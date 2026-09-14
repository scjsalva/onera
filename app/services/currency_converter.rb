# frozen_string_literal: true

# Converts a minor-unit amount between two currencies at an explicit rate.
#
# Rates are never looked up implicitly at read time. A caller either supplies
# the rate (manual entry) or asks ExchangeRateProvider for one, and the rate
# that was used is then written onto the financial record.
class CurrencyConverter
  Result = Struct.new(:amount_minor, :rate, keyword_init: true)

  def self.call(...) = new(...).call

  def initialize(amount_minor:, from:, to:, rate: nil, on: Date.current)
    @amount_minor = amount_minor.to_i
    @from = from
    @to = to
    @rate = rate
    @on = on
  end

  def call
    return Result.new(amount_minor:, rate: BigDecimal(1)) if from.code == to.code

    effective = resolved_rate
    raise ArgumentError, "no exchange rate available for #{from.code} -> #{to.code}" if effective.nil?

    # Move through major units so currencies with different exponents (JPY has
    # none, PHP has two) convert correctly, then round once, half-up.
    major = (BigDecimal(amount_minor) / from.subunit_factor) * effective
    Result.new(amount_minor: (major * to.subunit_factor).round(0, :half_up).to_i, rate: effective)
  end

  private

  attr_reader :amount_minor, :from, :to, :on

  def resolved_rate
    return normalize(@rate) if @rate.present?

    ExchangeRateProvider.new(from:, to:, on:).rate
  end

  def normalize(value) = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
end
