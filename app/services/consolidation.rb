# frozen_string_literal: true

# Restates a group's per-currency balances in a single currency.
#
# This is what the "settle everything in one currency" option is built on. It
# is a view until RateLocker writes the rates down: while any currency in the
# group is still unlocked the result is an estimate, and #estimated? says so
# for the UI to label.
#
# Conversion is applied to each person's net position rather than to each
# expense, and the rounding residual is absorbed by the largest position, so
# the converted balances still sum to exactly zero.
class Consolidation
  Line = Struct.new(:currency, :rate, :locked, :source_total_minor, :converted_minor, keyword_init: true) do
    def locked? = locked
    def source_total(currency_override = nil) = MoneyAmount.new(source_total_minor, currency_override || currency)
  end

  Entry = Struct.new(:user, :currency, :net_minor, keyword_init: true) do
    def net = MoneyAmount.new(net_minor, currency)
    def owed? = net_minor.positive?
    def owing? = net_minor.negative?
    def settled? = net_minor.zero?
  end

  def initialize(group:, calculator:, target_currency:, rates: {})
    @group = group
    @calculator = calculator
    @target_currency = target_currency
    @rates = rates.to_h.transform_keys(&:to_s).transform_values(&:presence).compact
  end

  attr_reader :target_currency

  def source_currencies
    @source_currencies ||= calculator.currencies.select { |currency| calculator.active_in?(currency.code) }
  end

  def rate_for(currency)
    return BigDecimal(1) if currency.code == target_currency.code

    override = @rates[currency.code]
    return BigDecimal(override.to_s) if override.present?

    locked_rate_for(currency) || ExchangeRateProvider.new(from: currency, to: target_currency).rate
  end

  def locked?(currency)
    return true if currency.code == target_currency.code

    group.expenses.active.where(currency_code: currency.code).where(rate_locked_at: nil).none?
  end

  def estimated? = source_currencies.any? { |currency| !locked?(currency) }

  def lines
    @lines ||= source_currencies.map do |currency|
      total = calculator.total_spend(currency).minor
      Line.new(
        currency:,
        rate: rate_for(currency),
        locked: locked?(currency),
        source_total_minor: total,
        converted_minor: convert(total, currency)
      )
    end
  end

  # One entry per member: their whole position in the group, in one currency.
  def entries
    @entries ||= begin
      raw = calculator.standings.to_h do |standing|
        converted = standing.positions.sum { |position| convert(position.net_minor, position.currency) }
        [ standing.user, converted ]
      end

      [ balanced(raw) ].flatten.map { |user, net| Entry.new(user:, currency: target_currency, net_minor: net) }
    end
  end

  def entry_for(user_id) = entries.detect { |entry| entry.user.id == user_id }

  # Fewest transfers that clear the group once everything is in one currency.
  def suggested_transfers
    creditors = entries.select(&:owed?).map { |e| [ e.user, e.net_minor ] }.sort_by { |(u, n)| [ -n, u.id ] }
    debtors = entries.select(&:owing?).map { |e| [ e.user, -e.net_minor ] }.sort_by { |(u, n)| [ -n, u.id ] }

    transfers = []
    ci = di = 0

    while ci < creditors.length && di < debtors.length
      creditor, credit = creditors[ci]
      debtor, debt = debtors[di]
      amount = [ credit, debt ].min

      if amount.positive?
        transfers << BalanceCalculator::Debt.new(
          from_user: debtor, to_user: creditor, currency: target_currency, amount_minor: amount
        )
      end

      creditors[ci] = [ creditor, credit - amount ]
      debtors[di] = [ debtor, debt - amount ]
      ci += 1 if creditors[ci][1].zero?
      di += 1 if debtors[di][1].zero?
    end

    transfers
  end

  def total_spend
    MoneyAmount.new(lines.sum(&:converted_minor), target_currency)
  end

  private

  attr_reader :group, :calculator

  def convert(minor, currency)
    return minor if minor.zero? || currency.code == target_currency.code

    sign = minor.negative? ? -1 : 1
    sign * CurrencyConverter.call(
      amount_minor: minor.abs, from: currency, to: target_currency, rate: rate_for(currency)
    ).amount_minor
  end

  def locked_rate_for(currency)
    group.expenses.active.rate_locked
         .where(currency_code: currency.code, base_currency_code: target_currency.code)
         .order(rate_locked_at: :desc)
         .pick(:exchange_rate)
  end

  # Net positions sum to zero in every source currency, so they must still sum
  # to zero after conversion. Rounding each one independently can leave a few
  # minor units of drift; it is absorbed by the largest position rather than
  # left to show up as a phantom debt.
  def balanced(raw)
    residual = raw.values.sum
    return raw if residual.zero? || raw.empty?

    anchor = raw.max_by { |_user, net| net.abs }.first
    raw.merge(anchor => raw[anchor] - residual)
  end
end
