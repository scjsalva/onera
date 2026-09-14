# frozen_string_literal: true

# The current user's position across every group they belong to, presented in
# their own primary currency.
#
# Group ledgers stay in their own currencies; this converts for display only.
# Where a group still has unlocked foreign expenses the figure is an estimate,
# and #estimated? tells the view to say so.
class DashboardCalculator
  GroupSummary = Struct.new(:group, :calculator, :consolidation, :display_currency, keyword_init: true) do
    def total_spend = consolidation.total_spend
    def estimated? = consolidation.estimated?

    def paid_minor = sum_positions(&:paid_minor)
    def share_minor = sum_positions(&:share_minor)

    def net_minor = consolidation.entry_for(viewer_id)&.net_minor.to_i
    def members = calculator.members
    def paid = MoneyAmount.new(paid_minor, display_currency)
    def share = MoneyAmount.new(share_minor, display_currency)
    def net = MoneyAmount.new(net_minor, display_currency)

    attr_accessor :viewer_id

    private

    def sum_positions(&block)
      standing = calculator.standing_for(viewer_id)
      return 0 if standing.nil?

      standing.positions.sum do |position|
        value = block.call(position)
        next 0 if value.zero?

        consolidation.send(:convert, value, position.currency)
      end
    end
  end

  Counterparty = Struct.new(:user, :net_minor, :currency, :breakdown, keyword_init: true) do
    def net = MoneyAmount.new(net_minor, currency)
    def owed? = net_minor.positive?
    def owing? = net_minor.negative?
  end

  BreakdownLine = Struct.new(:group, :net_minor, :currency, keyword_init: true) do
    def net = MoneyAmount.new(net_minor, currency)
  end

  def initialize(user, display_currency: nil)
    @user = user
    @display_currency = display_currency || user.preferred_currency
  end

  attr_reader :user, :display_currency

  # Active groups only: an archived group's balances leave your totals, which
  # is the point of archiving one.
  def groups
    @groups ||= user.groups.active.ordered.includes(:base_currency).to_a
  end

  # Everything the person has ever been in. Archiving hides a group from what
  # you are owed, but its spending is still part of where your money went.
  def all_group_ids
    @all_group_ids ||= user.groups.ids
  end

  def group_summaries
    @group_summaries ||= begin
      batch = BalanceCalculator::Batch.new(groups)

      groups.map do |group|
        calculator = batch.for(group)
        summary = GroupSummary.new(
          group:, calculator:,
          consolidation: calculator.consolidated(display_currency),
          display_currency:
        )
        summary.viewer_id = user.id
        summary
      end
    end
  end

  # Group activity plus the person's own ungrouped spending.
  def total_spend
    MoneyAmount.new(group_summaries.sum { |s| s.total_spend.minor } + personal_spend_minor, display_currency)
  end

  def total_paid
    MoneyAmount.new(group_summaries.sum(&:paid_minor) + personal_spend_minor, display_currency)
  end

  def total_share
    MoneyAmount.new(group_summaries.sum(&:share_minor) + personal_spend_minor, display_currency)
  end

  def personal_spend
    MoneyAmount.new(personal_spend_minor, display_currency)
  end

  # Expenses with no group that this person is on, whether they own them or
  # are only sharing them.
  def personal_expenses
    Expense.active.personal
           .where(owner_id: user.id)
           .or(Expense.active.personal.where(id: ExpenseSplit.where(user_id: user.id).select(:expense_id)))
  end

  def direct_ledger = @direct_ledger ||= DirectLedger.new(user)

  def owed_to_you = MoneyAmount.new(counterparties.select(&:owed?).sum(&:net_minor), display_currency)
  def you_owe = MoneyAmount.new(-counterparties.select(&:owing?).sum(&:net_minor), display_currency)
  def net_balance = MoneyAmount.new(counterparties.sum(&:net_minor), display_currency)

  def estimated? = group_summaries.any?(&:estimated?)

  # Who the current user owes and who owes them, netted per person across
  # every group, with the per-group breakdown kept for the detail view.
  # Presentation only - the underlying group debts are untouched.
  def counterparties
    @counterparties ||= begin
      totals = Hash.new(0)
      breakdown = Hash.new { |hash, key| hash[key] = [] }

      group_summaries.each do |summary|
        summary.calculator.currencies.each do |currency|
          next unless summary.calculator.active_in?(currency.code)

          summary.calculator.pairwise_debts(currency).each do |debt|
            amount = summary.consolidation.send(:convert, debt.amount_minor, currency)
            next if amount.zero?

            if debt.from_user.id == user.id
              totals[debt.to_user.id] -= amount
              breakdown[debt.to_user.id] << BreakdownLine.new(group: summary.group, net_minor: -amount, currency: display_currency)
            elsif debt.to_user.id == user.id
              totals[debt.from_user.id] += amount
              breakdown[debt.from_user.id] << BreakdownLine.new(group: summary.group, net_minor: amount, currency: display_currency)
            end
          end
        end
      end

      # Debts from expenses that belong to no group sit outside every group
      # summary, so they are folded in here or they would be invisible.
      direct_ledger.debts_for_me.each do |debt|
        amount = convert_to_display(debt.amount_minor, debt.currency.code)
        next if amount.zero?

        other, signed = debt.from_user.id == user.id ? [ debt.to_user, -amount ] : [ debt.from_user, amount ]
        totals[other.id] += signed
        breakdown[other.id] << BreakdownLine.new(group: nil, net_minor: signed, currency: display_currency)
      end

      people = User.where(id: totals.keys).index_by(&:id)
      totals.filter_map do |user_id, net|
        next if net.zero? || people[user_id].nil?

        Counterparty.new(user: people[user_id], net_minor: net, currency: display_currency,
                         breakdown: merge_breakdown(breakdown[user_id]))
      end.sort_by { |c| [ -c.net_minor.abs, c.user.name ] }
    end
  end

  def recent_expenses(limit: 8, filter: ExpenseFilter.new)
    ExpenseQuery.new(visible_expenses.involving(user.id), filter:).call
                .recent_first.limit(limit)
                .includes(:group, :category, :currency, :base_currency,
                          expense_payers: :user, expense_splits: :user)
  end

  def recent_settlements(limit: 6)
    Settlement.active.where(group_id: groups.map(&:id)).involving(user.id)
              .recent_first.limit(limit)
              .includes(:group, :payer, :recipient, :currency)
  end

  def recent_activity(limit: 12)
    ActivityEvent.for_groups(groups.map(&:id)).recent_first.limit(limit).includes(:actor, :group)
  end

  # Everything this person can see: their groups' expenses plus their own
  # personal ones.
  def visible_expenses
    Expense.where(group_id: all_group_ids).or(Expense.where(group_id: nil, owner_id: user.id))
  end

  # Spending by group, by category and by month, in the display currency.
  def spend_by_group
    group_summaries.map { |summary| [ summary.group, summary.total_spend ] }
                   .reject { |(_, total)| total.zero? }
                   .sort_by { |(_, total)| -total.minor }
  end

  def spend_by_category(filter: ExpenseFilter.new)
    rows = ExpenseQuery.new(visible_expenses.involving(user.id), filter:).call
                       .group("categories.name", "expenses.currency_code")
                       .sum("expenses.amount_minor")

    aggregate_by(rows) { |name, _| name || "Uncategorised" }
      .sort_by { |(_, total)| -total.minor }
  end

  def spend_by_month(months: 6, filter: ExpenseFilter.new)
    start = months.months.ago.beginning_of_month.to_date
    rows = ExpenseQuery.new(visible_expenses.involving(user.id).where(spent_on: start..), filter:).call
                       .group(Arel.sql("date_trunc('month', expenses.spent_on)"), "expenses.currency_code")
                       .sum("expenses.amount_minor")

    buckets = aggregate_by(rows) { |month, _| month.to_date.beginning_of_month }
    (0...months).map { |offset| (months - 1 - offset).months.ago.beginning_of_month.to_date }
                .map { |month| [ month, buckets[month] || MoneyAmount.zero(display_currency) ] }
  end

  private

  def personal_spend_minor
    @personal_spend_minor ||= personal_expenses.group(:currency_code).sum(:amount_minor)
                                               .sum { |code, minor| convert_to_display(minor, code) }
  end

  def convert_to_display(minor, currency_code)
    currency = currency_cache[currency_code]
    return 0 if currency.nil?
    return minor.to_i if currency.code == display_currency.code

    CurrencyConverter.call(amount_minor: minor.to_i, from: currency, to: display_currency).amount_minor
  end

  # Rows come back keyed by [something, currency_code]; fold them into the
  # display currency so mixed-currency spend can be compared.
  def aggregate_by(rows)
    rows.each_with_object({}) do |((dimension, currency_code), minor), memo|
      currency = currency_cache[currency_code]
      next if currency.nil?

      key = yield(dimension, currency_code)
      converted = if currency.code == display_currency.code
        minor.to_i
      else
        CurrencyConverter.call(amount_minor: minor.to_i, from: currency, to: display_currency).amount_minor
      end

      memo[key] = MoneyAmount.new((memo[key]&.minor).to_i + converted, display_currency)
    end
  end

  def currency_cache = @currency_cache ||= Currency.all.index_by(&:code)

  def merge_breakdown(lines)
    lines.group_by(&:group).map do |group, group_lines|
      BreakdownLine.new(group:, net_minor: group_lines.sum(&:net_minor), currency: display_currency)
    end.reject { |line| line.net_minor.zero? }.sort_by { |line| -line.net_minor.abs }
  end
end
