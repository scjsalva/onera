# frozen_string_literal: true

# The ledger between people who share no group.
#
# Group expenses have a group to scope them; direct ones only have the pair.
# This works out what one person owes another across every groupless expense
# and settlement they are both on, using the same apportionment rules as
# BalanceCalculator so the two agree.
class DirectLedger
  Debt = Struct.new(:from_user, :to_user, :currency, :amount_minor, keyword_init: true) do
    def amount = MoneyAmount.new(amount_minor, currency)
  end

  def initialize(user)
    @user = user
  end

  def expenses
    @expenses ||= Expense.active.personal
                         .where(id: ExpenseSplit.where(user_id: @user.id).select(:expense_id))
                         .or(Expense.active.personal.where(owner_id: @user.id))
                         .includes(:expense_payers, :expense_splits, :currency)
  end

  def settlements
    @settlements ||= Settlement.active.direct.involving(@user.id).includes(:payer, :recipient, :currency)
  end

  # Debts involving this person only. Someone else's direct expenses are none
  # of their business, and they can't see them anyway.
  # Memoized: the People page asks per row, and recomputing the whole ledger
  # for each friend walked every direct expense once per person on screen.
  def debts
    @debts ||= build_debts
  end

  def build_debts
    matrix = Hash.new(0)

    expenses.each do |expense|
      payer_weights = expense.expense_payers.map { |p| [ p.user_id, p.amount_minor ] }
      next if payer_weights.empty?

      expense.expense_splits.each do |split|
        next unless split.amount_minor.positive?

        owed = MinorUnitAllocator.allocate(total_minor: split.amount_minor, weights: payer_weights)
        owed.each do |payer_id, amount|
          next if payer_id == split.user_id || amount.zero?

          matrix[[ split.user_id, payer_id, expense.currency_code ]] += amount
        end
      end
    end

    settlements.each do |settlement|
      matrix[[ settlement.payer_id, settlement.recipient_id, settlement.currency_code ]] -= settlement.amount_minor
    end

    net(matrix)
  end

  # What this person owes, or is owed, per counterparty and currency.
  def debts_for_me
    @debts_for_me ||= debts.select { |d| [ d.from_user.id, d.to_user.id ].include?(@user.id) }
  end

  # Indexed by the other person, which is how the People page reads it.
  def debts_by_person
    @debts_by_person ||= debts_for_me.index_by { |d| d.from_user.id == @user.id ? d.to_user.id : d.from_user.id }
  end

  def spend_minor_by_currency
    expenses.group_by(&:currency_code).transform_values { |list| list.sum(&:amount_minor) }
  end

  private

  def net(matrix)
    seen = Set.new

    matrix.each_key.filter_map do |(a, b, code)|
      key = [ a, b ].sort << code
      next if seen.include?(key)

      seen << key
      value = matrix[[ a, b, code ]] - matrix[[ b, a, code ]]
      next if value.zero?

      debtor, creditor, amount = value.positive? ? [ a, b, value ] : [ b, a, -value ]
      from = people[debtor]
      to = people[creditor]
      next if from.nil? || to.nil?

      Debt.new(from_user: from, to_user: to, currency: currencies[code], amount_minor: amount)
    end
  end

  def people
    @people ||= User.where(id: (expenses.flat_map { |e| e.expense_splits.map(&:user_id) + e.expense_payers.map(&:user_id) } +
                                settlements.flat_map { |s| [ s.payer_id, s.recipient_id ] }).uniq).index_by(&:id)
  end

  def currencies = @currencies ||= Currency.all.index_by(&:code)
end
