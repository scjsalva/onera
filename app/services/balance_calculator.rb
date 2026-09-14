# frozen_string_literal: true

# Derives every balance in a group from the underlying records: expense
# payers, expense splits and settlements. Nothing here reads a stored balance
# and nothing here writes one.
#
# Balances are held per currency. A trip with yen and peso expenses carries a
# yen balance and a peso balance, and neither is converted unless somebody
# asks for it. Conversion is a decision made at settle-up, not an assumption
# baked into the ledger - see RateLocker.
class BalanceCalculator
  # One person's position in one currency.
  Position = Struct.new(:user, :currency, :paid_minor, :share_minor,
                        :settled_paid_minor, :settled_received_minor, :net_minor, keyword_init: true) do
    def paid = MoneyAmount.new(paid_minor, currency)
    def share = MoneyAmount.new(share_minor, currency)
    def settled_paid = MoneyAmount.new(settled_paid_minor, currency)
    def settled_received = MoneyAmount.new(settled_received_minor, currency)
    def net = MoneyAmount.new(net_minor, currency)
    def owed? = net_minor.positive?
    def owing? = net_minor.negative?
    def settled? = net_minor.zero?
    def any_activity? = !(paid_minor.zero? && share_minor.zero? &&
                          settled_paid_minor.zero? && settled_received_minor.zero?)
  end

  # Everything one person is owed or owes, across every currency in the group.
  Standing = Struct.new(:user, :positions, keyword_init: true) do
    def active_positions = positions.reject(&:settled?)
    def owed_positions = positions.select(&:owed?)
    def owing_positions = positions.select(&:owing?)
    def settled? = positions.all?(&:settled?)
    def position_in(code) = positions.detect { |p| p.currency.code == code }
  end

  Debt = Struct.new(:from_user, :to_user, :currency, :amount_minor, keyword_init: true) do
    def amount = MoneyAmount.new(amount_minor, currency)
  end

  def initialize(group)
    @group = group
  end

  # Every currency the group has actually transacted in, group primary first.
  def currencies
    @currencies ||= begin
      codes = (expenses.distinct.pluck(:currency_code) +
               settlements.distinct.pluck(:currency_code) +
               [ group.base_currency_code ]).uniq
      ordered = Currency.where(code: codes).index_by(&:code)
      ([ group.base_currency_code ] + (codes - [ group.base_currency_code ]).sort)
        .filter_map { |code| ordered[code] }
    end
  end

  def multi_currency? = currencies.count { |c| active_in?(c.code) } > 1

  def standings
    @standings ||= members.map do |user|
      positions = currencies.map { |currency| position_for(user, currency) }
      Standing.new(user:, positions:)
    end
  end

  def standing_for(user_id) = standings.detect { |s| s.user.id == user_id }

  def positions_in(currency)
    standings.filter_map { |standing| standing.position_in(currency.code) }
  end

  # Real outstanding debts per currency: who owes whom, netted per pair, after
  # settlements. This is ledger truth, not a suggestion.
  def pairwise_debts(currency)
    matrix = Hash.new(0)

    expense_debts(currency).each { |pair, amount| matrix[pair] += amount }
    settlements.active.where(currency_code: currency.code).each do |settlement|
      matrix[[ settlement.payer_id, settlement.recipient_id ]] -= settlement.amount_minor
    end

    net_matrix(matrix, currency)
  end

  # A recommendation layer, derived purely from net positions, suggesting the
  # fewest transfers that clear the currency. It never rewrites a record.
  def simplified_debts(currency)
    positions = positions_in(currency)
    creditors = positions.select(&:owed?).map { |p| [ p.user, p.net_minor ] }.sort_by { |(u, n)| [ -n, u.id ] }
    debtors = positions.select(&:owing?).map { |p| [ p.user, -p.net_minor ] }.sort_by { |(u, n)| [ -n, u.id ] }

    transfers = []
    ci = di = 0

    while ci < creditors.length && di < debtors.length
      creditor, credit = creditors[ci]
      debtor, debt = debtors[di]
      amount = [ credit, debt ].min

      transfers << Debt.new(from_user: debtor, to_user: creditor, currency:, amount_minor: amount) if amount.positive?

      creditors[ci] = [ creditor, credit - amount ]
      debtors[di] = [ debtor, debt - amount ]
      ci += 1 if creditors[ci][1].zero?
      di += 1 if debtors[di][1].zero?
    end

    transfers
  end

  def total_spend(currency) = MoneyAmount.new(expense_totals.fetch(currency.code, 0), currency)
  def total_settled(currency) = MoneyAmount.new(settlement_totals.fetch(currency.code, 0), currency)

  def outstanding(currency)
    MoneyAmount.new(positions_in(currency).select(&:owed?).sum(&:net_minor), currency)
  end

  def active_in?(code)
    expense_totals.key?(code) || settlement_totals.key?(code)
  end

  # The whole group restated in one currency. Locked expenses use their locked
  # rate; anything still unlocked is converted indicatively, and the caller is
  # expected to label it as an estimate.
  def consolidated(target_currency, rates: {})
    Consolidation.new(group:, calculator: self, target_currency:, rates:)
  end

  private

  attr_reader :group

  def members = @members ||= group.users.ordered.to_a
  def expenses = @expenses ||= group.expenses.active
  def settlements = @settlements ||= group.settlements

  def position_for(user, currency)
    code = currency.code
    paid = paid_totals.dig(code, user.id).to_i
    share = share_totals.dig(code, user.id).to_i
    out = settlements_paid.dig(code, user.id).to_i
    incoming = settlements_received.dig(code, user.id).to_i

    Position.new(
      user:, currency:,
      paid_minor: paid, share_minor: share,
      settled_paid_minor: out, settled_received_minor: incoming,
      net_minor: paid - share + out - incoming
    )
  end

  def expense_totals
    @expense_totals ||= expenses.group(:currency_code).sum(:amount_minor)
  end

  def settlement_totals
    @settlement_totals ||= settlements.active.group(:currency_code).sum(:amount_minor)
  end

  def paid_totals
    @paid_totals ||= nest(
      ExpensePayer.joins(:expense).merge(expenses)
                  .group("expenses.currency_code", :user_id).sum(:amount_minor)
    )
  end

  def share_totals
    @share_totals ||= nest(
      ExpenseSplit.joins(:expense).merge(expenses)
                  .group("expenses.currency_code", :user_id).sum(:amount_minor)
    )
  end

  def settlements_paid
    @settlements_paid ||= nest(settlements.active.group(:currency_code, :payer_id).sum(:amount_minor))
  end

  def settlements_received
    @settlements_received ||= nest(settlements.active.group(:currency_code, :recipient_id).sum(:amount_minor))
  end

  def nest(grouped)
    grouped.each_with_object({}) do |((code, user_id), amount), memo|
      (memo[code] ||= {})[user_id] = amount.to_i
    end
  end

  # For each expense, every participant owes each payer in proportion to what
  # that payer put in, apportioned so the parts sum back exactly.
  def expense_debts(currency)
    debts = Hash.new(0)

    expenses.where(currency_code: currency.code)
            .includes(:expense_payers, :expense_splits).find_each do |expense|
      payer_weights = expense.expense_payers.map { |p| [ p.user_id, p.amount_minor ] }
      next if payer_weights.empty?

      expense.expense_splits.each do |split|
        next unless split.amount_minor.positive?

        owed = MinorUnitAllocator.allocate(total_minor: split.amount_minor, weights: payer_weights)
        owed.each do |payer_id, amount|
          next if payer_id == split.user_id || amount.zero?

          debts[[ split.user_id, payer_id ]] += amount
        end
      end
    end

    debts
  end

  def net_matrix(matrix, currency)
    seen = Set.new

    matrix.each_key.filter_map do |(a, b)|
      pair = [ a, b ].sort
      next if seen.include?(pair)

      seen << pair
      net = matrix[[ a, b ]] - matrix[[ b, a ]]
      next if net.zero?

      debtor, creditor, amount = net.positive? ? [ a, b, net ] : [ b, a, -net ]
      from = users_by_id[debtor]
      to = users_by_id[creditor]
      next if from.nil? || to.nil?

      Debt.new(from_user: from, to_user: to, currency:, amount_minor: amount)
    end.sort_by { |debt| [ -debt.amount_minor, debt.from_user.name ] }
  end

  def users_by_id
    @users_by_id ||= User.where(
      id: (members.map(&:id) + settlements.pluck(:payer_id, :recipient_id).flatten).uniq
    ).index_by(&:id)
  end
end
