# frozen_string_literal: true

require "test_helper"

class CurrencyConverterTest < ActiveSupport::TestCase
  test "the same currency converts to itself at one" do
    result = CurrencyConverter.call(amount_minor: 5000, from: php, to: php)

    assert_equal 5000, result.amount_minor
    assert_equal BigDecimal(1), result.rate
  end

  test "crossing exponents converts through major units" do
    # ¥8,400 (no decimals) at 0.39 is ₱3,276.00 (two decimals).
    result = CurrencyConverter.call(amount_minor: 8400, from: jpy, to: php, rate: "0.39")

    assert_equal 327_600, result.amount_minor
  end

  test "converting back the other way crosses exponents too" do
    result = CurrencyConverter.call(amount_minor: 327_600, from: php, to: jpy, rate: "2.5641")

    assert_equal 8400, result.amount_minor
  end

  test "rounding is half up and happens once" do
    result = CurrencyConverter.call(amount_minor: 1, from: jpy, to: php, rate: "0.395")

    assert_equal 40, result.amount_minor
  end

  test "an unknown pair raises rather than silently returning the input" do
    Currency.create!(code: "ZZZ", name: "Nowhere", symbol: "Z", exponent: 2)

    assert_raises(ArgumentError) do
      CurrencyConverter.call(amount_minor: 100, from: Currency.find("ZZZ"), to: jpy)
    end
  end

  test "a seeded pair resolves without an explicit rate" do
    ExchangeRate.find_or_create_by!(base_currency_code: "JPY", quote_currency_code: "PHP",
                                    rate_date: 1.year.ago.to_date) { |r| r.rate = BigDecimal("0.39") }

    result = CurrencyConverter.call(amount_minor: 100, from: jpy, to: php)

    assert_equal BigDecimal("0.39"), result.rate
  end

  test "an unseeded pair triangulates through the pivot currency" do
    ExchangeRate.find_or_create_by!(base_currency_code: "JPY", quote_currency_code: "PHP",
                                    rate_date: 1.year.ago.to_date) { |r| r.rate = BigDecimal("0.39") }
    ExchangeRate.find_or_create_by!(base_currency_code: "USD", quote_currency_code: "PHP",
                                    rate_date: 1.year.ago.to_date) { |r| r.rate = BigDecimal("58.20") }

    rate = ExchangeRateProvider.new(from: jpy, to: usd).rate

    assert_in_delta 0.0067, rate.to_f, 0.0005
  end
end
