# frozen_string_literal: true

# The only place the app resolves an exchange rate it was not handed.
#
# Rates come from the exchange_rates table, which is seeded and can be edited
# by hand. There is no live feed wired up, so nothing in the UI claims rates
# are live. Swapping in a real provider means implementing #remote_rate here
# and leaving every caller untouched.
class ExchangeRateProvider
  PIVOT_CODE = "PHP"

  def initialize(from:, to:, on: Date.current)
    @from = from
    @to = to
    @on = on
  end

  def rate
    return BigDecimal(1) if from_code == to_code

    direct_rate || inverse_rate || pivot_rate
  end

  # The most recent rate on or before the given date, so backdating an expense
  # uses the rate that was current then rather than today's.
  def self.latest_pairs(base_code)
    ExchangeRate.where(base_currency_code: base_code)
                .order(:quote_currency_code, rate_date: :desc)
                .select("DISTINCT ON (quote_currency_code) *")
  end

  private

  attr_reader :on

  def from_code = @from.is_a?(String) ? @from : @from.code
  def to_code = @to.is_a?(String) ? @to : @to.code

  def direct_rate
    lookup(from_code, to_code)&.rate
  end

  def inverse_rate
    found = lookup(to_code, from_code)
    return if found.nil?

    (BigDecimal(1) / found.rate).round(12)
  end

  # Most rates are seeded against a single pivot currency rather than as every
  # possible pair, so an unseeded pair (JPY -> SGD) is resolved through it.
  def pivot_rate
    pivot = PIVOT_CODE
    return if [ from_code, to_code ].include?(pivot)

    from_pivot = self.class.new(from: from_code, to: pivot, on:).send(:direct_or_inverse)
    to_target = self.class.new(from: pivot, to: to_code, on:).send(:direct_or_inverse)
    return if from_pivot.nil? || to_target.nil?

    (from_pivot * to_target).round(12)
  end

  def direct_or_inverse = direct_rate || inverse_rate

  # The rate in force on the given date. If the table only holds rates from
  # after that date - a backdated expense, or a currency added recently - the
  # earliest known rate is used rather than refusing to convert at all.
  def lookup(base, quote)
    scope = ExchangeRate.where(base_currency_code: base, quote_currency_code: quote)
    scope.where(rate_date: ..on).order(rate_date: :desc).first ||
      scope.order(:rate_date).first
  end
end
