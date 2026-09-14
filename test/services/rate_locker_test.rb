# frozen_string_literal: true

require "test_helper"

class RateLockerTest < ActiveSupport::TestCase
  setup do
    @john = create_user(name: "John", username: "johnrl")
    @alice = create_user(name: "Alice", username: "alicerl")
    @group = create_group(members: [ @john, @alice ], creator: @john, currency: "PHP")

    @expense = add_expense(group: @group, actor: @john, amount: "10000", currency_code: "JPY",
                           payers: [ { user_id: @john.id, amount: "10000" } ],
                           participants: [ @john, @alice ].map { |u| { user_id: u.id } })
  end

  test "before locking, the conversion is only indicative" do
    assert_equal "indicative", @expense.rate_source
    refute @expense.rate_locked?
    assert @expense.indicative_rate?
  end

  test "a same-currency expense needs no lock" do
    native = add_expense(group: @group, actor: @john, amount: "500",
                         payers: [ { user_id: @john.id, amount: "500" } ],
                         participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    assert_equal "native", native.rate_source
    assert native.rate_locked?
  end

  test "locking writes the chosen rate onto the expense" do
    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.41" })
    @expense.reload

    assert_equal "locked", @expense.rate_source
    assert_equal BigDecimal("0.41"), @expense.exchange_rate
    assert_equal 410_000, @expense.base_amount_minor
    assert @expense.rate_locked_at.present?
  end

  test "locking keeps payers and splits reconciled with the converted total" do
    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.41" })
    @expense.reload

    assert_equal @expense.base_amount_minor, @expense.expense_payers.sum(&:base_amount_minor)
    assert_equal @expense.base_amount_minor, @expense.expense_splits.sum(&:base_amount_minor)
  end

  test "a rate that does not divide evenly still reconciles" do
    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.333333" })
    @expense.reload

    assert_equal @expense.base_amount_minor, @expense.expense_splits.sum(&:base_amount_minor)
  end

  test "locking twice does not re-convert the first lock" do
    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.41" })
    first = @expense.reload.base_amount_minor

    result = RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.99" })

    assert_equal first, @expense.reload.base_amount_minor
    refute result.success?
  end

  test "editing a locked expense reuses its rate" do
    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.41" })

    ExpenseUpdater.call(expense: @expense.reload, actor: @john, params: {
      description: "Edited", currency_code: "JPY", amount: "20000",
      spent_on: Date.current, split_method: "equal",
      payers: [ { user_id: @john.id, amount: "20000" } ],
      participants: [ @john, @alice ].map { |u| { user_id: u.id } }
    })
    @expense.reload

    assert_equal BigDecimal("0.41"), @expense.exchange_rate
    assert_equal 820_000, @expense.base_amount_minor
  end

  test "a rate that is not a positive number is refused" do
    result = RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "-1" })

    refute result.success?
    assert_equal "indicative", @expense.reload.rate_source
  end

  test "locking records a revision so the change can be explained" do
    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.41" })

    assert_includes @expense.revisions.pluck(:action), "rate_locked"
  end

  test "the target currency can differ from the group's" do
    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "1" },
                    target_currency: Currency.find("USD"))
    @expense.reload

    assert_equal "USD", @expense.base_currency_code
  end
end
