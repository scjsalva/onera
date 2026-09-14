# frozen_string_literal: true

require "test_helper"

class ExpenseWriterTest < ActiveSupport::TestCase
  setup do
    @john = create_user(name: "John", username: "johnw")
    @alice = create_user(name: "Alice", username: "alicew")
    @outsider = create_user(name: "Outsider", username: "outsiderw")
    @group = create_group(members: [ @john, @alice ], creator: @john)
  end

  def create_expense(**params)
    ExpenseCreator.call(group: @group, actor: @john, params: {
      description: "Thing", currency_code: "PHP", amount: "1000",
      spent_on: Date.current, split_method: "equal",
      payers: [ { user_id: @john.id, amount: "1000" } ],
      participants: [ { user_id: @john.id }, { user_id: @alice.id } ]
    }.merge(params))
  end

  test "a straightforward expense is stored with reconciled splits" do
    result = create_expense

    assert result.success?
    assert_equal 100_000, result.expense.amount_minor
    assert_equal 100_000, result.expense.expense_splits.sum(&:amount_minor)
  end

  test "payer amounts that do not add up are refused" do
    result = create_expense(payers: [ { user_id: @john.id, amount: "400" } ])

    refute result.success?
    assert_match(/add up/, result.errors.join)
  end

  test "an amount of zero is refused" do
    result = create_expense(amount: "0", payers: [ { user_id: @john.id, amount: "0" } ])

    refute result.success?
    assert_match(/greater than zero/, result.errors.join)
  end

  test "a negative amount is refused" do
    result = create_expense(amount: "-50", payers: [ { user_id: @john.id, amount: "-50" } ])

    refute result.success?
  end

  test "an expense with no payer is refused" do
    result = create_expense(payers: [])

    refute result.success?
    assert_match(/who paid/i, result.errors.join)
  end

  test "an expense with nobody sharing it is refused" do
    result = create_expense(participants: [])

    refute result.success?
    assert_match(/sharing/i, result.errors.join)
  end

  test "somebody outside the group cannot be put on an expense" do
    result = create_expense(participants: [ { user_id: @john.id }, { user_id: @outsider.id } ])

    refute result.success?
    assert_match(/member of the group/i, result.errors.join)
  end

  test "a client-supplied total is ignored in favour of the real maths" do
    result = create_expense(split_method: "equal")
    shares = result.expense.expense_splits.map(&:amount_minor)

    assert_equal [ 50_000, 50_000 ], shares
  end

  test "a foreign currency is converted only as an estimate" do
    result = create_expense(currency_code: "JPY", amount: "1000",
                            payers: [ { user_id: @john.id, amount: "1000" } ])

    assert result.success?
    assert_equal "indicative", result.expense.rate_source
    assert_equal "JPY", result.expense.currency_code
    assert_equal "PHP", result.expense.base_currency_code
  end

  test "editing recalculates the split from scratch" do
    expense = create_expense.expense

    ExpenseUpdater.call(expense:, actor: @john, params: {
      description: "Bigger", currency_code: "PHP", amount: "3000",
      spent_on: Date.current, split_method: "percentage",
      payers: [ { user_id: @john.id, amount: "3000" } ],
      participants: [ { user_id: @john.id, split_value: "75" }, { user_id: @alice.id, split_value: "25" } ]
    })
    expense.reload

    assert_equal 300_000, expense.amount_minor
    assert_equal [ 225_000, 75_000 ], expense.expense_splits.order(:user_id).pluck(:amount_minor).sort.reverse
  end

  test "an edit that would not balance leaves the expense alone" do
    expense = create_expense.expense

    result = ExpenseUpdater.call(expense:, actor: @john, params: {
      description: "Broken", currency_code: "PHP", amount: "3000",
      spent_on: Date.current, split_method: "percentage",
      payers: [ { user_id: @john.id, amount: "3000" } ],
      participants: [ { user_id: @john.id, split_value: "10" }, { user_id: @alice.id, split_value: "10" } ]
    })

    refute result.success?
    assert_equal 100_000, expense.reload.amount_minor
  end

  test "a voided expense cannot be edited" do
    expense = create_expense.expense
    ExpenseVoider.call(expense:, actor: @john)

    result = ExpenseUpdater.call(expense: expense.reload, actor: @john, params: {
      description: "Nope", amount: "5000", currency_code: "PHP", spent_on: Date.current,
      split_method: "equal",
      payers: [ { user_id: @john.id, amount: "5000" } ],
      participants: [ { user_id: @john.id } ]
    })

    refute result.success?
  end

  test "voiding twice is refused rather than double-counted" do
    expense = create_expense.expense
    ExpenseVoider.call(expense:, actor: @john)

    refute ExpenseVoider.call(expense: expense.reload, actor: @john).success?
  end

  test "a voided expense can be restored" do
    expense = create_expense.expense
    ExpenseVoider.call(expense:, actor: @john)
    ExpenseVoider.new(expense: expense.reload, actor: @john).restore

    assert expense.reload.active?
  end

  test "a personal expense belongs to its owner and splits with nobody" do
    result = ExpenseCreator.call(owner: @john, actor: @john, params: {
      description: "Coffee", currency_code: "PHP", amount: "150", spent_on: Date.current
    })

    assert result.success?
    assert result.expense.personal?
    assert_equal @john, result.expense.owner
    assert_equal 1, result.expense.expense_splits.count
  end

  test "every write leaves a revision behind" do
    expense = create_expense.expense
    ExpenseUpdater.call(expense:, actor: @john, params: {
      description: "Edited", currency_code: "PHP", amount: "1000", spent_on: Date.current,
      split_method: "equal",
      payers: [ { user_id: @john.id, amount: "1000" } ],
      participants: [ { user_id: @john.id }, { user_id: @alice.id } ]
    })
    ExpenseVoider.call(expense: expense.reload, actor: @john)

    assert_equal %w[created edited voided], expense.revisions.chronological.pluck(:action)
  end
end
