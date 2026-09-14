# Testing

Four layers, each catching what the one below it cannot.

```bash
bin/check   # everything except the browser suite - fast, run it constantly
bin/e2e     # real Chrome, complete journeys - slower, run it before pushing
```

## What runs

**`bin/check`**

| Step | What it protects |
| --- | --- |
| `zeitwerk:check` | Every class loads; no naming mistakes |
| Vite build (dev + test) | The stylesheet and bundle actually compile |
| Rubocop | House style |
| Brakeman (`-w2`) | Injection, mass assignment, unsafe redirects |
| Route crawl | Every page renders — catches template syntax errors |
| Minitest | Models, services, queries, request flows |
| Vitest | Vue components and the money helpers |

**`bin/e2e`** drives real Chrome through complete journeys — signing in,
creating a group, adding an expense, settling up, recovering an account — and
fails on any JavaScript error or 5xx that happens along the way, even if the
assertions pass.

## Databases

Three, deliberately separate:

- `onera_development` — yours, never touched by tests
- `onera_test` — Minitest, wrapped in transactions
- `onera_e2e` — the browser suite, which commits real rows

They were one for a while, and the browser suite's leftovers made unit tests
that count records fail in ways that looked like real bugs.

## The browser driver

`test/browser/driver.mjs` speaks the Chrome DevTools Protocol directly rather
than pulling in Cypress or Playwright. It is about 250 lines and gives what
these journeys need: navigate, click something by its visible text or its
accessible name, type into a field through the native setter so Vue's
`v-model` notices, read the page, and report layout problems.

Every protocol call is bounded by a timeout. Without that, one promise in the
page that never settles hangs the whole suite with no output at all — which
happened, and looked exactly like a slow test.

## Writing a journey

```js
scenario('a short password is refused', async (b) => {
  await signIn(b, 'someone');
  await b.goto(`${BASE}/password/edit`);
  await b.fill('#current_password', 'password');
  await b.fill('#password', 'short');
  await b.clickText('Change password');
  check(await b.has('8 characters'), 'should require a minimum length');
});
```

Two things worth knowing:

- Text matching is case-insensitive, because `innerText` reflects CSS
  `text-transform` and half the labels here are uppercased in CSS.
- Icon-only controls have no text. Use `clickLabel`, which matches the
  accessible name — the same thing a screen reader would use.

## What the tests have actually caught

Not hypotheticals — each of these was found by a test and fixed:

- Password confirmation was never validated, so a typo created an account with
  a password nobody knew. Fixing that then revealed that closing an account
  had been silently failing to scramble the password.
- The expense composer dropped its amount when moving to the second step,
  because a `v-if` unmounted the fields.
- An unterminated CSS comment took out the entire stylesheet build, while the
  page still rendered unstyled.
- Numeric props arrive from HAML as strings, and the money formatter padded to
  twenty-one characters.
- The email prompt intercepted every page rather than once per sign-in, which
  made the profile unreachable for anyone without an email.
- Amount filters assumed two decimal places, quietly excluding every
  zero-decimal currency.
- An entrance animation could leave content permanently invisible.

## What is not covered

- No load or performance testing.
- The browser suite runs one Chrome, not a matrix. Safari and Firefox are
  unexercised.
- Exchange rates come from a table, so no provider integration is stubbed.
