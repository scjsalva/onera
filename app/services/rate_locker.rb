# frozen_string_literal: true

# Locks the exchange rates on a group's foreign-currency expenses.
#
# Until this runs, a foreign expense carries an indicative conversion that is
# only ever shown as a guide. Locking picks one rate per currency, restates the
# expense, its payers and its splits in the group's base currency, and freezes
# them. From that point the expense's contribution to every balance is fixed,
# and no later rate movement can rewrite it.
class RateLocker
  Result = Struct.new(:locked_count, :currencies, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  # A currency awaiting a lock, with the rate we would suggest for it.
  Pending = Struct.new(:currency, :expense_count, :total_minor, :suggested_rate, keyword_init: true) do
    def total = MoneyAmount.new(total_minor, currency)
  end

  def self.pending_for(group, target_currency: nil)
    target = target_currency || group.base_currency

    group.expenses.active.where(rate_locked_at: nil).where.not(currency_code: target.code)
         .group(:currency_code)
         .pluck(Arel.sql("currency_code, COUNT(*), SUM(amount_minor)"))
         .filter_map do |code, count, total|
           currency = Currency.find_by(code:)
           next if currency.nil?

           Pending.new(
             currency:,
             expense_count: count,
             total_minor: total.to_i,
             suggested_rate: ExchangeRateProvider.new(from: currency, to: target).rate
           )
         end.sort_by { |pending| pending.currency.code }
  end

  def self.call(...) = new(...).call

  # rates: { "JPY" => "0.39", "USD" => "58.20" } - one rate per currency.
  # target_currency defaults to the group's primary currency but is chosen by
  # the user at settle-up, so a trip can be settled in yen even when the group
  # is denominated in pesos.
  def initialize(group:, actor:, rates:, target_currency: nil)
    @group = group
    @actor = actor
    @rates = rates.to_h.transform_keys(&:to_s).transform_values { |v| v.presence }
    @target = target_currency || group.base_currency
    @errors = []
  end

  def call
    pending = RateLocker.pending_for(group, target_currency: target)
    return Result.new(locked_count: 0, currencies: [], errors: [ "There are no foreign expenses to convert" ]) if pending.empty?

    resolved = resolve_rates(pending)
    return Result.new(locked_count: 0, currencies: [], errors:) if errors.any?

    locked = 0

    ActiveRecord::Base.transaction do
      resolved.each do |code, rate|
        group.expenses.active.where(rate_locked_at: nil, currency_code: code)
             .includes(:expense_payers, :expense_splits).find_each do |expense|
          lock_expense(expense, rate)
          locked += 1
        end

        ActivityRecorder.record(
          action: "group.rates_locked",
          summary: "#{actor&.name || 'Someone'} locked #{code} at #{rate.to_s('F')} #{target.code}",
          group:, actor:,
          metadata: { currency: code, rate: rate.to_s("F") }
        )
      end
    end

    Result.new(locked_count: locked, currencies: resolved.keys, errors: [])
  end

  private

  attr_reader :group, :actor, :rates, :target, :errors

  def resolve_rates(pending)
    pending.each_with_object({}) do |item, memo|
      code = item.currency.code
      raw = rates[code].presence || item.suggested_rate

      if raw.blank?
        errors << "Enter a rate for #{code}"
        next
      end

      value = BigDecimal(raw.to_s) rescue nil
      if value.nil? || !value.positive?
        errors << "The rate for #{code} must be a positive number"
        next
      end

      memo[code] = value
    end
  end

  def lock_expense(expense, rate)
    converted = CurrencyConverter.call(
      amount_minor: expense.amount_minor,
      from: expense.currency,
      to: target,
      rate: rate
    )

    payer_base = MinorUnitAllocator.allocate(
      total_minor: converted.amount_minor,
      weights: expense.expense_payers.map { |p| [ p.id, p.amount_minor ] }
    )
    split_base = MinorUnitAllocator.allocate(
      total_minor: converted.amount_minor,
      weights: expense.expense_splits.map { |s| [ s.id, s.amount_minor ] }
    )

    expense.expense_payers.each { |p| p.update!(base_amount_minor: payer_base.fetch(p.id, 0)) }
    expense.expense_splits.each { |s| s.update!(base_amount_minor: split_base.fetch(s.id, 0)) }

    expense.update!(
      base_currency_code: target.code,
      exchange_rate: converted.rate,
      base_amount_minor: converted.amount_minor,
      rate_locked_at: Time.current,
      rate_locked_by: actor,
      rate_source: "locked"
    )

    RevisionRecorder.record(expense, action: "rate_locked", actor:,
                                     changed_fields: { exchange_rate: rate.to_s("F") })
  end
end
