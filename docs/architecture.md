# Architecture

## Shape

A Rails monolith. Rails owns routing, controllers, models, the database, every
financial calculation, and server rendering. Vue enhances the interactive parts
of pages Rails renders.

```
Browser
   │
   ├── HAML rendered by Rails
   │      └── Vue components mounted over it (one app, global registration)
   │
   └── /api/split_previews, /api/conversions
          └── the same services that persist, called for preview only

Rails
   ├── controllers/   thin - parse params, call a service, render
   ├── services/      all business and financial logic
   ├── queries/       filtering and search, expressed in SQL
   ├── presenters/    the shapes handed to Vue
   └── models/        persistence, validation, invariants

PostgreSQL
```

There is no separate frontend app, no API-only mode, and no client-side router.

## Why Vue is mounted this way

One Vue app is mounted on `#vue` in the layout and every component is registered
globally, so a HAML template can drop `%expense-composer{...}` anywhere and pass
props as JSON attributes. This mirrors the pattern in the larger Rails app this
project is modelled on.

The alternative — a component per page with its own mount point — means more
wiring per screen for no benefit here, since Rails is already rendering the page.

## The preview boundary

The expense form shows live split figures and an approximate conversion. Both
come from `/api/split_previews`, which calls the same `SplitCalculator` and
`CurrencyConverter` used on save.

The client still sends only raw inputs — description, amount, currency, who
paid, who shares, the split method and its values. Every derived figure is
recomputed by `ExpenseWriter` on submit. A tampered or stale preview cannot put
a wrong number in the database; the worst it can do is show the user something
that changes when they save.

## Services

Named for what they do, not for a pattern:

| Service | Responsibility |
| --- | --- |
| `SplitCalculator` | Resolve a split method and inputs into exact per-person shares |
| `MinorUnitAllocator` | Apportion a whole into weighted parts that sum back to it |
| `CurrencyConverter` | Convert between currencies at an explicit rate |
| `ExchangeRateProvider` | Resolve a rate from the table; triangulate via PHP |
| `ExpenseWriter` | Shared create/update machinery — validate, convert, rebuild children |
| `ExpenseCreator` / `ExpenseUpdater` / `ExpenseVoider` | The three write paths |
| `SettlementCreator` / `SettlementUpdater` / `SettlementVoider` | Same, for payments |
| `RateLocker` | The one binding conversion, performed at settle-up |
| `BalanceCalculator` | Per-currency positions, pairwise debts, simplification |
| `Consolidation` | Restate those positions in a single chosen currency |
| `DashboardCalculator` | One person's position across every group |
| `DirectLedger` | Balances between people who share no group |
| `Timeline` | Expenses and settlements merged into one chronological list |
| `RecoveryCodeIssuer` / `RecoveryCodeRedeemer` | Offline password recovery |
| `RevisionRecorder` / `ActivityRecorder` | Append-only history |

Plain CRUD does not get a service. `GroupsController#update` calls
`@group.update`, because there is no logic to extract.

## Query strategy

Per-person totals are `GROUP BY` aggregates in PostgreSQL, not Ruby loops over
records. Filtering and search are a single relation built by `ExpenseQuery`;
search uses `ILIKE` over the expense plus `EXISTS` subqueries against payer and
participant names, so nothing is loaded to be discarded.

One calculation is deliberately in Ruby: the pairwise debt matrix. Working out
what each participant owes each payer needs exact apportionment per expense,
which is rounding logic rather than arithmetic SQL can express. It is bounded by
group size and preloaded, and it is the only place a group's expenses are walked.

## Current user

`Current.user` — an `ActiveSupport::CurrentAttributes` — is set once per
request in `ApplicationController#set_current_user`. Nothing else in the app
reads the session or Devise's helpers directly.

That seam was the whole point. Introducing real authentication changed one
line — `Current.user = warden.user` — and nothing in the financial domain at
all. It is worth keeping intact.

## Two ledgers

`BalanceCalculator` scopes to a group. `DirectLedger` handles expenses that
belong to no group, between people who have added each other.

They are separate because their scoping questions differ — one is "everything
in this group", the other "everything between this pair" — but they apportion
money with the same `MinorUnitAllocator`, so their answers agree.
`DashboardCalculator` folds both into one figure per person.

## Frontend conventions

- Components live in `app/javascript/src/components` and are auto-registered by
  filename, so `BottomSheet.vue` is `%bottom-sheet`.
- Props arrive as JSON strings on HTML attributes; components parse defensively
  because the same prop may be an object in a test and a string in a template.
- Motion is centralised: `lib/reveal.js` drives entrance animations for
  server-rendered markup via `data-reveal`, and everything collapses under
  `prefers-reduced-motion`.

### A HAML trap worth knowing

Tailwind classes containing `/` or a decimal cannot go in HAML dot-notation.
HAML reads `.bg-white/10` as a self-closing tag and splits `.py-2.5` into two
classes. Put those in an explicit attribute:

```haml
%div.rounded-xl.px-3{ class: "bg-white/10 py-2.5" }
```
