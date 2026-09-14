# frozen_string_literal: true

require "test_helper"

class ConsolidationTest < ActiveSupport::TestCase
  setup do
    @john = create_user(name: "John", username: "johnc")
    @alice = create_user(name: "Alice", username: "alicec")
    @bob = create_user(name: "Bob", username: "bobc")
    @group = create_group(members: [ @john, @alice, @bob ], creator: @john)

    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })
    add_expense(group: @group, actor: @alice, amount: "3000", currency_code: "JPY",
                payers: [ { user_id: @alice.id, amount: "3000" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })
  end

  def consolidation(rates: {}) = BalanceCalculator.new(@group.reload).consolidated(php, rates:)

  test "converted balances still sum to zero" do
    assert_equal 0, consolidation.entries.sum(&:net_minor)
  end

  test "an awkward rate cannot leave a phantom balance" do
    assert_equal 0, consolidation(rates: { "JPY" => "0.377" }).entries.sum(&:net_minor)
    assert_equal 0, consolidation(rates: { "JPY" => "0.001" }).entries.sum(&:net_minor)
  end

  test "an unlocked currency marks the result as an estimate" do
    assert consolidation.estimated?
  end

  test "locking every currency clears the estimate" do
    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.39" })

    refute consolidation.estimated?
  end

  test "suggested transfers move exactly what is owed" do
    result = consolidation
    owed = result.entries.select(&:owed?).sum(&:net_minor)

    assert_equal owed, result.suggested_transfers.sum(&:amount_minor)
  end

  test "nobody is asked to pay themselves" do
    assert consolidation.suggested_transfers.none? { |t| t.from_user == t.to_user }
  end

  test "a settled group needs no transfers" do
    settled = create_group(name: "Settled", members: [ @john, @alice ], creator: @john)

    assert_empty BalanceCalculator.new(settled).consolidated(php).suggested_transfers
  end
end
