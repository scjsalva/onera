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
bin/dev                # Rails + Vite together
```

Then open http://localhost:3000 and pick who you are.

`db:prepare` loads reference data (currencies, categories, exchange rates) plus
a demo dataset in development: four people, four groups, mixed currencies, every
split type, an edited expense, a voided one, and partial settlements.

To start clean:

```bash
SKIP_DEMO_DATA=1 bin/rails db:reset
```

## Authentication

There isn't any, deliberately. You pick a person on first load and that choice
lives in the session.

`User` is a real model and the domain identity — one person is one row across
every group they appear in. Everything reads `Current.user`; nothing in the
financial code touches the session. Adding real sign-in means changing
`ApplicationController#set_current_user` and nothing else.

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
