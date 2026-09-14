# Onera

Shared expenses, settled without the spreadsheet.

A Rails monolith for splitting costs across groups and people: multi-payer
expenses, four ways to split them, balances held per currency, and a settle-up
flow that decides when — and whether — anything gets converted.

Vue is embedded in the Rails app for the interactive parts. There is no
separate frontend, no API-only backend, and no SPA.

---

## Running it locally

Requires Ruby 3.4.2, Node 22, and PostgreSQL.

```bash
bundle install
npm install
bin/rails db:prepare   # creates, migrates, and seeds
bin/dev                # Rails + Vite together on :3000
```

Sign in with any of the seeded usernames — `scjsalva`, `cnasayao`,
`ljvalencia`, `kaflores`, `egblance`, `aegonia` — and the password
`password`.

`db:prepare` loads reference data (currencies, categories, exchange rates) and
the accounts. Demo groups and expenses are opt-in:

```bash
SEED_DEMO_DATA=1 bin/rails db:reset   # sample trips, mixed currencies, settlements
SKIP_DEMO_DATA=1 bin/rails db:reset   # accounts and reference data only
```

## Accounts

Sign in with a **username**, or an email once you've added one. Email is
optional for using Onera but required to recover an account — a username is
visible to everyone in your groups, so allowing a reset against one would let
any member start a recovery for anybody else. The app asks for an email once
per sign-in until you give it.

**There is no public sign-up.** Someone already inside shares an invite link
and the new person creates their own account. The link is built from the
request, so it is correct on localhost, on a preview deploy and in production
without anything to configure.

**Password recovery is by offline codes**, not email. Ten single-use codes,
shown once when generated, redeemed against your email address. This is why
the app is useful the moment it's deployed: no mail service, no domain
verification, no deliverability problems. Only digests are stored.

Lost both password and codes? From a console:

```bash
bin/rails onera:codes ONERA_USERNAME=scjsalva      # what they have, and what is spent
bin/rails onera:password ONERA_USERNAME=scjsalva   # issue a new password
```

The seeded accounts and their `password` password exist in development only.
A deployed instance starts with no accounts at all — see `docs/deployment.md`.

**Closing an account** anonymizes rather than deletes. Expenses and
settlements point at the user row, so removing it would either orphan
financial history or cascade a delete through records the app promises never
to destroy. Name, email and birthday are erased; the person becomes "Removed
person 3", keeps their own number and colour so two of them are never alike,
and can never sign in again.

`Current.user` was the seam all of this hung on. Introducing real
authentication changed one line — where it gets set — and nothing in the
financial domain at all.

## How money works

Three rules the rest of the app is built on.

**Nothing is stored as a float.** Every amount is an integer count of minor
units alongside a currency whose `exponent` says where the decimal point goes,
so ¥ (no decimals) and ₱ (two) need no special cases. `MoneyAmount` wraps it.

**Splits always reconcile.** `SplitCalculator` divides a total by the largest
remainder method: floor everyone's exact share, then hand the leftover minor
units to the largest fractional parts, earliest participant first. ₱100 across
three people is ₱33.34 / ₱33.33 / ₱33.33 — never ₱99.99. The tie-break is
deterministic, so editing an expense doesn't reshuffle who absorbed the odd cent.

**Balances are derived, never stored.** Every figure comes from expenses,
payers, splits and settlements at read time. There are no balance columns to
drift out of sync, and any total can be rebuilt from the ledger.

## Currencies

Currency precedence is: **the group's currency where there is a group, the
owner's own currency otherwise.** Groups have a primary currency (default PHP,
changeable per group); each person has one too, used for their own cross-group
totals and for personal expenses.

Balances are held **per currency**. A trip with yen and peso expenses carries a
yen balance and a peso balance, and neither is converted into the other. That's
the honest representation: a debt incurred in yen is a yen debt.

Conversion therefore happens twice, for two different reasons:

1. **At entry, as a guide.** Typing a foreign amount shows a quiet
   "about ₱3,276" underneath. It is recalculated on every edit, labelled as an
   estimate, and the money does not follow it.
2. **At settle-up, as the decision.** Consolidating locks one rate per currency
   onto the underlying expenses — the expense, its payers and its splits are all
   restated — and stamps `rate_locked_at`. From then on that rate is frozen: no
   later rate movement rewrites it, and editing the expense reuses it.

Consolidating is optional. Settle-up offers two routes: pay each currency
separately and convert nothing, or convert everything into one currency
(defaulting to the group's, editable at that step).

There is no live rate feed. Rates come from the `exchange_rates` table and can
be typed in by hand, so nothing in the UI claims they are live. Unseeded pairs
are triangulated through PHP. Wiring up a provider means implementing one method
in `ExchangeRateProvider`.

## How it moves

Turbo Drive swaps pages in place, so navigating does not flash white, lose
your scroll position or re-fetch avatars. Pages cross-fade while the top and
tab bars stay put.

On a phone it takes gestures, not just taps:

- **Swipe an expense row** left to edit, right to void. A long swipe fires
  straight away; a short one rests the row open so you can tap the action.
- **Hold a row** for the same actions, for anyone who would rather not swipe.
- **Pull the add button upward** to open the composer. It follows your thumb
  and springs back if you let go early.
- Haptics where the device offers them, and every animation collapses under
  `prefers-reduced-motion`.

## The timeline

A group's Expenses tab and the global list interleave settlements with
expenses, in one chronological list. The order is the story — two expenses,
then somebody paying somebody back — and splitting them across tabs made you
reconstruct it in your head. Settlement rows are tinted and inset so they read
as something that happened *between* the expenses rather than as one of them.

Filters that describe an expense (a category, a currency, who paid) hide the
settlements, since those filters have no meaning for a payment.

## Archiving a group

For a trip that is over. From **Settings** inside a group:

- It moves to Archived in your groups list and stays readable.
- Nobody can add expenses or record payments in it.
- Anything still unsettled stops counting towards what you owe or are owed.
- Its spending still appears in your insights — it happened, after all.
- Everyone in the group is told.
- You can reopen it from the same place, and everything comes back.

A group holding any money is archived rather than deleted, whichever button
was pressed. Only a group with nothing in it can actually be deleted.

## Nothing is deleted

Expenses and settlements are **voided**, not destroyed. A voided record keeps
its row, stays visible, is clearly marked, and stops counting towards balances.
Every create, edit, void and rate lock writes a `Revision` snapshot and an
`ActivityEvent`, so any historical figure can be explained.

Debt simplification is presentation only. Switching to the simplified view
changes what is drawn and nothing else.

## Layout

```
app/
  models/       ActiveRecord plus MoneyAmount, the value object for money
  services/     all financial logic - calculators, writers, the rate locker
  queries/      ExpenseFilter and ExpenseQuery (filtering and search, in SQL)
  presenters/   the shapes handed to Vue
  controllers/  thin; they call a service and render
  views/        HAML
  javascript/   Vue 3 components, built by Vite
```

Controllers hold no money logic. See `docs/architecture.md` and
`docs/financial-model.md`.

## Deploying

Any host that runs a Dockerfile and reaches a Postgres database.

The included `render.yaml` and `fly.toml` both build the Dockerfile, run
migrations and reference seeds on boot, and health-check `/up`. Point
`DATABASE_URL` at a free Neon or Supabase database rather than a host's own free
tier — those tend to expire, and the whole point is that the data persists.

Required environment: `DATABASE_URL`, `SECRET_KEY_BASE`, `APP_HOST`. See
`.env.example`. Demo data is opt-in via `SEED_DEMO_DATA`.

## Tests

Not written yet — a deliberate choice to get the application working end to end
first. The domain is structured for them: the calculators are plain objects with
no Rails coupling, and the seeds already exercise every path through them.
