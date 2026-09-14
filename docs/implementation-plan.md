# Implementation plan and status

## Done

**Foundation** — Rails 8 monolith, PostgreSQL, HAML, Vite, Vue 3, Tailwind,
structured after the larger Rails app this is modelled on (`app/services`,
`app/queries`, `app/presenters`) but without its accumulated complexity.

**Domain** — users, groups, memberships, categories, currencies, exchange rates,
expenses with separate payer/participant/split tables, settlements, activity
events, revisions. Constraints and indexes in the database, not only the models.

**Money** — `MoneyAmount` over integer minor units; `SplitCalculator` with four
methods and largest-remainder rounding; `MinorUnitAllocator` shared by splitting
and conversion; per-currency `BalanceCalculator`; `Consolidation`; `RateLocker`.

**Identity** — global `User`, session-based picker, `Current.user`, profile with
a personal primary currency.

**Interface** — mobile-first app shell (bottom tab bar with a centre action,
sidebar from `md`), bottom sheets for compose/settle/filter/switch, staggered
reveals, count-up figures, animated charts, reduced-motion support.

**Screens** — global dashboard, groups list, group overview/expenses/balances/
payments/people/activity, expense detail with history, settle-up, cross-group
balances, activity, insights, profile, person creation.

**Deployment** — Dockerfile that builds the Vite bundle, `render.yaml`,
`fly.toml`, health check, migrations and reference seeds on boot, demo data
opt-in.

## Verified by hand

Run against the seeded data and over HTTP:

- net positions sum to zero in every currency, before and after consolidation
- pairwise and simplified debts agree on totals
- ₱100 ÷ 3 and ¥8,401 ÷ 3 reconcile exactly
- creating a grouped expense and a personal one
- editing a rate-locked expense reuses the locked rate rather than re-converting
- voiding removes an expense from balances while keeping it visible
- rate locking rewrites expense, payer and split base amounts consistently
- every route renders; the production image boots and serves compiled assets

## Not done yet

**Tests.** Agreed to come after the application worked end to end. The domain is
arranged for them: the calculators are plain objects with no Rails coupling, and
the seeds already drive every path.

Worth covering first, in rough order of risk:

1. `SplitCalculator` — the four methods, rounding, invalid totals
2. `MinorUnitAllocator` — reconciliation, negative residues, single bucket
3. `BalanceCalculator` — multi-payer, payer-not-participant, settlements, voids
4. `Consolidation` — zero-sum after conversion, locked versus estimated rates
5. `RateLocker` — locks once, never re-converts, keeps children consistent
6. `ExpenseWriter` — rejects client-supplied totals that don't add up
7. Request specs for the create/edit/void/settle paths

**Smaller gaps**

- The global expense filter accepts `group_id=personal` in the UI but the query
  object treats it as an id; personal-only filtering needs a branch.
- Amount range filters compare against the converted figure, which is
  indicative for unlocked foreign expenses.
- Settlement editing exists; settlement voiding is wired but has no UI entry
  point outside the edit screen.
- No pagination. The global expense list caps at 200 rows.
