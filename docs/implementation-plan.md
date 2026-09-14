# What is built, and what is not

## Built

**Foundation** — Rails 8 monolith, PostgreSQL, HAML, Vite, Vue 3, Tailwind,
structured after the larger Rails app this is modelled on (`app/services`,
`app/queries`, `app/presenters`) without its accumulated complexity.

**Money** — integer minor units throughout, `MoneyAmount` as the value object,
four split methods with largest-remainder rounding that always reconciles, and
one allocator shared by splitting and currency conversion.

**Currencies** — balances held per currency, never silently merged. An
indicative conversion at entry time for the "about ₱3,276" guide, and one
binding conversion at settle-up that freezes a rate onto the expense, its
payers and its splits. Consolidating is optional.

**Accounts** — username or email sign-in, optional email asked for once per
sign-in, invite-link signup, offline recovery codes, and account closure by
anonymizing rather than deleting.

**Visibility** — friendships gate who you can see and split with outside a
group. A shared group connects two strangers inside it and nowhere else.

**Two ledgers** — `BalanceCalculator` per group, `DirectLedger` per pair with
no group. Both apportion the same way; the dashboard folds them together.

**Interface** — mobile-first app shell, bottom sheets for every compose flow,
glass materials, light and dark themes, staggered reveals, illustrated avatars
with initials as fallback, one icon scale, and a timeline that interleaves
settlements with expenses.

**Notifications** — in-app, on the bell, for the events that affect someone's
money or membership.

**Testing** — 260 Ruby tests, Vitest over the Vue layer, a route crawl, and a
browser suite driving real Chrome. `bin/check` and `bin/e2e`.

**Deployment** — Dockerfile that builds the frontend, `render.yaml`, a
keep-alive schedule, CI workflow, health check, migrations and reference seeds
on boot.

## Deliberately not built

**Email and SMS delivery.** Both need a paid service and a verified sender.
Recovery works offline instead, which is why the app is usable the moment it
is deployed. `Notifier.deliver` is the one seam a channel would be added to.

**A live exchange-rate feed.** Rates come from a table and can be typed in.
Nothing claims they are live. `ExchangeRateProvider` is where a provider goes.

## Known gaps

- **No pagination.** The global expense list caps at 200 rows and the group
  list is unbounded. Fine for a personal app, wrong for a large one.
- **`DashboardCalculator#counterparties` walks each group's expenses in Ruby**
  to apportion debts exactly. Bounded by group size and preloaded, but it is
  the heaviest query path and the first thing to cache if it ever matters.
- **Amount filters compare the converted figure**, which is indicative for
  expenses whose rate is not yet locked.
- **Voiding a settlement has no UI entry point** outside its edit screen.
- **Group archiving is one-way** in the interface; unarchiving needs a console.
- **The browser suite runs one Chrome.** Safari and Firefox are unexercised.
