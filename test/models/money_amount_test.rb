# frozen_string_literal: true

require "test_helper"

class MoneyAmountTest < ActiveSupport::TestCase
  test "renders two-decimal currencies with grouping" do
    assert_equal "₱12,345.67", MoneyAmount.new(1_234_567, php).format
  end

  test "renders zero-decimal currencies without a decimal point" do
    assert_equal "¥840,000", MoneyAmount.new(840_000, jpy).format
  end

  test "a negative amount keeps the sign outside the symbol" do
    assert_equal "-₱12.34", MoneyAmount.new(-1234, php).format
  end

  test "an explicit plus is only added when asked for" do
    assert_equal "+₱1.00", MoneyAmount.new(100, php).format(sign: true)
    assert_equal "₱1.00", MoneyAmount.new(100, php).format
    assert_equal "₱0.00", MoneyAmount.new(0, php).format(sign: true)
  end

  test "from_major rounds half up rather than truncating" do
    assert_equal 1235, MoneyAmount.from_major("12.345", php).minor
    assert_equal 1234, MoneyAmount.from_major("12.344", php).minor
  end

  test "from_major respects a zero-decimal currency" do
    assert_equal 8400, MoneyAmount.from_major("8400", jpy).minor
    assert_equal 8400, MoneyAmount.from_major("8400.4", jpy).minor
  end

  test "from_major never goes through a float" do
    # 1.005 is famously not representable; the decimal path must still round up.
    assert_equal 101, MoneyAmount.from_major("1.005", php).minor
  end

  test "to_input gives a plain value for a form field" do
    assert_equal "12.34", MoneyAmount.new(1234, php).to_input
    assert_equal "8400", MoneyAmount.new(8400, jpy).to_input
  end

  test "arithmetic stays in the same currency" do
    sum = MoneyAmount.new(100, php) + MoneyAmount.new(250, php)

    assert_equal 350, sum.minor
    assert_equal "PHP", sum.currency.code
  end

  test "combining two currencies is refused rather than guessed" do
    assert_raises(MoneyAmount::CurrencyMismatch) do
      MoneyAmount.new(100, php) + MoneyAmount.new(100, jpy)
    end
  end

  test "comparisons work within a currency" do
    assert MoneyAmount.new(200, php) > MoneyAmount.new(100, php)
    assert_equal MoneyAmount.new(100, php), MoneyAmount.new(100, php)
  end

  test "predicates read the sign" do
    assert MoneyAmount.new(-1, php).negative?
    assert MoneyAmount.new(1, php).positive?
    assert MoneyAmount.new(0, php).zero?
  end

  test "amounts are frozen so they cannot be mutated in place" do
    assert MoneyAmount.new(100, php).frozen?
  end
end
