# The financial model

## Money

Every amount is an integer count of minor units plus a currency. The currency
row carries an `exponent`, so ¥8,400 is `8400` with exponent 0 and ₱84.00 is
`8400` with exponent 2. `MoneyAmount` is the value object; it refuses to combine
two different currencies.

Nothing in the domain holds money as a Float. User input is parsed through
`BigDecimal` and rounded half-up exactly once, on the way in.

## Tables

```
users                    one person, globally
groups                   name, description, primary currency
group_memberships        unique on (group_id, user_id)

expenses                 group_id NULL for a personal expense
expense_payers           who put money in, and how much
expense_participants     who it is shared between, plus the raw split input
expense_splits           the resolved share per person - server-written only

settlements              a real payment from one person to another
currencies               code, symbol, exponent
exchange_rates           base, quote, rate, date

activity_events          append-only human-readable history
revisions                polymorphic snapshots of expenses and settlements
```

`expense_participants` holds *intent* (a percentage, an exact amount, a share
count). `expense_splits` holds the *resolved money*. Keeping them apart is what
lets an expense be re-split on edit without losing what the user actually asked
for.

Revisions are one polymorphic table rather than `expense_revisions` and
`settlement_revisions`: the shape is identical and the question "what happened
to this record" is then one query.

## Invariants

Enforced in the database with check constraints and in the models:

- payer amounts sum to the expense total
- split amounts sum to the expense total
- percentages sum to 100; exact amounts sum to the total; shares are positive
- amounts and exchange rates are positive
- a settlement's payer and recipient differ
- everyone on a group expense is a member of that group
- a personal expense involves only its owner
- one membership per person per group

## Splitting

`SplitCalculator` takes a total in minor units, a method, and the participants'
raw inputs.

- **Equal** — everyone weighted 1.
- **Percentage** — weighted by percentage; rejected unless they total 100.
- **Exact** — amounts used directly; rejected unless they total the expense.
- **Shares** — weighted by share count.

Everything except exact goes through `MinorUnitAllocator`: floor each exact
share, then distribute the leftover minor units to the largest fractional parts,
ties broken by participant order.

```
₱100.00 ÷ 3  →  3334, 3333, 3333   (sums to 10000)
¥8,401  ÷ 3  →  2801, 2800, 2800   (sums to 8401)
```

The allocation is deterministic, so recalculating after an edit produces the
same distribution rather than quietly moving the odd cent to someone else.

Adding a fifth split method means adding a branch and a weight function. The
reconciliation guarantee comes free from the allocator.

## Currencies and the two conversions

Currency precedence: the group's currency when there is a group, the owner's
own currency otherwise.

Balances are held per currency. A group is not forced into a single
denomination, because a yen debt is a yen debt.

**Conversion one — the guide.** When an expense is entered in a foreign
currency, it is converted at today's known rate so the form can show
"about ₱3,276". This is written to `base_amount_minor` with
`rate_source = 'indicative'` and recalculated on every edit. It exists for
display and for making mixed-currency lists comparable. It is labelled as an
estimate everywhere it appears.

**Conversion two — the decision.** At settle-up the group may consolidate. The
person settling picks a target currency (defaulting to the group's) and a rate
per currency. `RateLocker` then converts each affected expense, re-apportions
the converted total across its payers and splits so the parts still sum to the
whole, writes `rate_locked_at`, and records a revision.

A locked rate is permanent. Editing a locked expense reuses it rather than
re-converting at a newer one, so a historical figure never silently moves.

Consolidating is optional. The alternative is to pay each currency separately,
in which case nothing is ever converted.

## Balances

For each person, in each currency:

```
net = paid - share + settlements_paid - settlements_received
```

Positive means the group owes them. Per currency, the nets sum to exactly zero.

**Pairwise debts** are the real ledger. For each expense, every participant owes
each payer in proportion to what that payer contributed, apportioned exactly;
the matrix is then netted per pair and reduced by settlements.

**Simplified debts** are a suggestion derived only from net positions — greedily
matching the largest creditor to the largest debtor. It is a presentation layer.
Viewing it changes nothing.

**Consolidated balances** convert each person's net position rather than each
expense. Converting a set of numbers that sums to zero can leave a few minor
units of rounding residue, which is absorbed by the largest position so the
converted balances still sum to zero and no phantom debt appears.

## Voiding

Financial records are never deleted. A voided expense keeps its row, is excluded
from `Expense.active`, and therefore from every balance and total, while staying
visible and clearly marked. Settlements work the same way. Both are reversible,
and both write a revision either way.

Removing a person from a group is refused if they appear anywhere in its ledger,
rather than cascading a delete through financial history.
