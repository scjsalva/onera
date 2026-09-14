# frozen_string_literal: true

require "test_helper"

class BalanceCalculatorTest < ActiveSupport::TestCase
  setup do
    @john = create_user(name: "John", username: "john")
    @alice = create_user(name: "Alice", username: "alice")
    @bob = create_user(name: "Bob", username: "bob")
    @group = create_group(members: [ @john, @alice, @bob ], creator: @john)
  end

  def calculator = BalanceCalculator.new(@group.reload)

  def net(user, currency = php)
    calculator.standing_for(user.id).position_in(currency.code).net_minor
  end

  test "one payer, three sharers" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    assert_equal 60_000, net(@john)
    assert_equal(-30_000, net(@alice))
    assert_equal(-30_000, net(@bob))
    assert_equal 0, calculator.positions_in(php).sum(&:net_minor)
  end

  test "a payer who is not a participant is owed the whole amount" do
    add_expense(group: @group, actor: @john, amount: "600",
                payers: [ { user_id: @john.id, amount: "600" } ],
                participants: [ @alice, @bob ].map { |u| { user_id: u.id } })

    assert_equal 60_000, net(@john)
    assert_equal(-30_000, net(@alice))
  end

  test "several payers on one expense" do
    add_expense(group: @group, actor: @john, amount: "3000",
                payers: [ { user_id: @john.id, amount: "2000" }, { user_id: @alice.id, amount: "1000" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    assert_equal 100_000, net(@john)
    assert_equal 0, net(@alice)
    assert_equal(-100_000, net(@bob))
  end

  test "a settlement clears the debt it pays" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    SettlementCreator.call(group: @group, actor: @alice, params: {
      payer_id: @alice.id, recipient_id: @john.id, currency_code: "PHP",
      amount: "300", settled_on: Date.current
    })

    assert_equal 30_000, net(@john)
    assert_equal 0, net(@alice)
  end

  test "a partial settlement leaves the remainder" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    SettlementCreator.call(group: @group, actor: @alice, params: {
      payer_id: @alice.id, recipient_id: @john.id, currency_code: "PHP",
      amount: "100", settled_on: Date.current
    })

    assert_equal(-20_000, net(@alice))
  end

  test "a voided expense stops counting" do
    expense = add_expense(group: @group, actor: @john, amount: "900",
                          payers: [ { user_id: @john.id, amount: "900" } ],
                          participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    ExpenseVoider.call(expense:, actor: @john)

    assert_equal 0, net(@john)
    assert_equal 0, net(@alice)
    assert_equal 0, calculator.total_spend(php).minor
  end

  test "currencies are kept apart rather than merged" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })
    add_expense(group: @group, actor: @alice, amount: "1000", currency_code: "JPY",
                payers: [ { user_id: @alice.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    assert_equal 45_000, net(@john, php)
    assert_equal(-500, net(@john, jpy))
    assert_equal 0, calculator.positions_in(php).sum(&:net_minor)
    assert_equal 0, calculator.positions_in(jpy).sum(&:net_minor)
  end

  test "pairwise debts say who owes whom" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    debts = calculator.pairwise_debts(php)

    assert_equal 2, debts.size
    assert debts.all? { |d| d.to_user == @john }
    assert_equal [ 30_000, 30_000 ], debts.map(&:amount_minor)
  end

  test "debts between the same pair net off" do
    add_expense(group: @group, actor: @john, amount: "1000",
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })
    add_expense(group: @group, actor: @alice, amount: "400",
                payers: [ { user_id: @alice.id, amount: "400" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    debts = calculator.pairwise_debts(php)

    assert_equal 1, debts.size
    assert_equal @alice, debts.first.from_user
    assert_equal 30_000, debts.first.amount_minor
  end

  test "simplification moves the same total in fewer transfers" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })
    add_expense(group: @group, actor: @alice, amount: "300",
                payers: [ { user_id: @alice.id, amount: "300" } ],
                participants: [ @bob ].map { |u| { user_id: u.id } })

    simplified = calculator.simplified_debts(php)

    assert_equal calculator.positions_in(php).select(&:owed?).sum(&:net_minor),
                 simplified.sum(&:amount_minor)
    assert simplified.none? { |d| d.from_user == d.to_user }
  end

  test "simplification changes nothing in the ledger" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    before = ExpenseSplit.order(:id).pluck(:amount_minor, :base_amount_minor)
    calculator.simplified_debts(php)

    assert_equal before, ExpenseSplit.order(:id).pluck(:amount_minor, :base_amount_minor)
  end

  test "an empty group has nothing to say and does not blow up" do
    empty = create_group(name: "Empty", members: [ @john ], creator: @john)
    calc = BalanceCalculator.new(empty)

    assert_equal 0, calc.total_spend(php).minor
    assert_empty calc.pairwise_debts(php)
    assert_empty calc.simplified_debts(php)
  end
end
