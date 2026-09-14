# frozen_string_literal: true

require "test_helper"

class SplitCalculatorTest < ActiveSupport::TestCase
  def split(total, method, participants, currency: php)
    SplitCalculator.new(total_minor: total, split_method: method, participants:, currency:).call
  end

  def people(*values)
    values.each_with_index.map { |value, index| { user_id: index + 1, value: } }
  end

  test "an equal split reconciles to the total" do
    result = split(10_000, "equal", people(nil, nil, nil))

    assert result.valid?
    assert_equal 10_000, result.allocations.values.sum
    assert_equal [ 3334, 3333, 3333 ], result.allocations.values
  end

  test "the odd unit goes to the earliest participant, every time" do
    5.times do
      assert_equal [ 3334, 3333, 3333 ], split(10_000, "equal", people(nil, nil, nil)).allocations.values
    end
  end

  test "a zero-decimal currency divides in whole units" do
    result = split(8401, "equal", people(nil, nil, nil), currency: jpy)

    assert_equal [ 2801, 2800, 2800 ], result.allocations.values
    assert_equal 8401, result.allocations.values.sum
  end

  test "percentages must total one hundred" do
    result = split(10_000, "percentage", people(70, 20))

    refute result.valid?
    assert_match(/100%/, result.errors.first)
  end

  test "percentages that total one hundred apportion exactly" do
    result = split(90_000, "percentage", people(50, 30, 20))

    assert result.valid?
    assert_equal [ 45_000, 27_000, 18_000 ], result.allocations.values
  end

  test "an awkward percentage still reconciles" do
    result = split(10_000, "percentage", people(33.33, 33.33, 33.34))

    assert result.valid?
    assert_equal 10_000, result.allocations.values.sum
  end

  test "exact amounts must add up to the total" do
    result = split(100_000, "fixed", people("500", "300", "100"))

    refute result.valid?
    assert_match(/add up to/, result.errors.first)
  end

  test "exact amounts that add up are used verbatim" do
    result = split(100_000, "fixed", people("500", "300", "200"))

    assert result.valid?
    assert_equal [ 50_000, 30_000, 20_000 ], result.allocations.values
  end

  test "shares divide proportionally" do
    result = split(10_000, "shares", people(2, 1, 1))

    assert_equal [ 5000, 2500, 2500 ], result.allocations.values
  end

  test "shares that do not divide evenly still reconcile" do
    result = split(10_000, "shares", people(1, 1, 1))

    assert_equal 10_000, result.allocations.values.sum
  end

  test "a single participant takes the whole amount" do
    assert_equal [ 10_000 ], split(10_000, "equal", people(nil)).allocations.values
  end

  test "no participants is refused rather than dividing by zero" do
    result = split(10_000, "equal", [])

    refute result.valid?
    assert_match(/at least one person/, result.errors.first)
  end

  test "a zero total is refused" do
    result = split(0, "equal", people(nil, nil))

    refute result.valid?
    assert_match(/greater than zero/, result.errors.first)
  end

  test "shares of zero across the board are refused" do
    result = split(10_000, "shares", people(0, 0))

    refute result.valid?
    assert_match(/more than zero/, result.errors.first)
  end

  test "a participant with zero shares simply pays nothing" do
    result = split(9000, "shares", people(2, 1, 0))

    assert result.valid?
    assert_equal [ 6000, 3000, 0 ], result.allocations.values
    assert_equal 9000, result.allocations.values.sum
  end

  test "an unknown split method is refused" do
    refute split(1000, "sideways", people(nil)).valid?
  end

  test "one minor unit across three people loses nothing" do
    result = split(1, "equal", people(nil, nil, nil))

    assert_equal 1, result.allocations.values.sum
    assert_equal [ 1, 0, 0 ], result.allocations.values
  end

  test "a large amount across many people reconciles" do
    participants = 17.times.map { |i| { user_id: i + 1, value: nil } }
    result = SplitCalculator.new(total_minor: 1_000_003, split_method: "equal",
                                 participants:, currency: php).call

    assert_equal 1_000_003, result.allocations.values.sum
  end
end
