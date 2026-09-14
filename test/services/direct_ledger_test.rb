# frozen_string_literal: true

require "test_helper"

class DirectLedgerTest < ActiveSupport::TestCase
  setup do
    @a = create_user(name: "Ann", username: "annl")
    @b = create_user(name: "Ben", username: "benl")
    @c = create_user(name: "Cal", username: "call")
    Friendship.request(from: @a, to: @b).accept!
    Friendship.request(from: @a, to: @c).accept!
  end

  def direct(owner:, with:, amount: "500", currency: "PHP")
    result = ExpenseCreator.call(owner:, actor: owner, params: {
      description: "Direct", currency_code: currency, amount:, spent_on: Date.current,
      split_method: "equal",
      payers: [ { user_id: owner.id, amount: } ],
      participants: [ { user_id: owner.id }, { user_id: with.id } ]
    })
    raise result.errors.join(", ") unless result.success?

    result.expense
  end

  test "an even split leaves half owing" do
    direct(owner: @a, with: @b)
    debt = DirectLedger.new(@a).debts_for_me.first

    assert_equal @b, debt.from_user
    assert_equal @a, debt.to_user
    assert_equal 25_000, debt.amount_minor
  end

  test "both people see the same debt from their own side" do
    direct(owner: @a, with: @b)

    assert_equal DirectLedger.new(@a).debts_for_me.first.amount_minor,
                 DirectLedger.new(@b).debts_for_me.first.amount_minor
  end

  test "debts between the same pair net off" do
    direct(owner: @a, with: @b, amount: "1000")
    direct(owner: @b, with: @a, amount: "400")

    debts = DirectLedger.new(@a).debts_for_me

    assert_equal 1, debts.size
    assert_equal @b, debts.first.from_user
    assert_equal 30_000, debts.first.amount_minor
  end

  test "currencies stay apart" do
    direct(owner: @a, with: @b, amount: "1000", currency: "PHP")
    direct(owner: @a, with: @b, amount: "1000", currency: "JPY")

    debts = DirectLedger.new(@a).debts_for_me

    assert_equal 2, debts.size
    assert_equal %w[JPY PHP], debts.map { |d| d.currency.code }.sort
  end

  test "a direct settlement clears the debt" do
    direct(owner: @a, with: @b)

    Settlement.create!(payer: @b, recipient: @a, currency_code: "PHP", base_currency_code: "PHP",
                       amount_minor: 25_000, base_amount_minor: 25_000, settled_on: Date.current)

    assert_empty DirectLedger.new(@a).debts_for_me
  end

  test "a partial settlement leaves the remainder" do
    direct(owner: @a, with: @b, amount: "1000")

    Settlement.create!(payer: @b, recipient: @a, currency_code: "PHP", base_currency_code: "PHP",
                       amount_minor: 20_000, base_amount_minor: 20_000, settled_on: Date.current)

    assert_equal 30_000, DirectLedger.new(@a).debts_for_me.first.amount_minor
  end

  test "someone else's direct expenses are none of your business" do
    direct(owner: @a, with: @b)

    assert_empty DirectLedger.new(@c).debts_for_me
  end

  test "a solo expense creates no debt" do
    ExpenseCreator.call(owner: @a, actor: @a, params: {
      description: "Coffee", currency_code: "PHP", amount: "120", spent_on: Date.current
    })

    assert_empty DirectLedger.new(@a).debts_for_me
  end

  test "voiding removes the debt" do
    expense = direct(owner: @a, with: @b)
    ExpenseVoider.call(expense:, actor: @a)

    assert_empty DirectLedger.new(@a).debts_for_me
  end

  test "the ledger is computed once, not once per person asking" do
    direct(owner: @a, with: @b)
    ledger = DirectLedger.new(@a)

    ledger.debts_for_me
    # The People page reads this per row; a second walk per friend was a real
    # query multiplier on that page.
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].to_s.include?("SCHEMA") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      3.times { ledger.debts_for_me }
    end

    assert_equal 0, queries
  end

  test "debts can be looked up by the other person" do
    direct(owner: @a, with: @b)

    by_person = DirectLedger.new(@a).debts_by_person

    assert_equal 25_000, by_person[@b.id].amount_minor
    assert_nil by_person[@c.id]
  end

  test "a single minor unit is absorbed by whoever paid, not half-owed" do
    # ₱0.01 between two people: the odd unit goes to the first participant,
    # who is also the payer, so nobody owes a fraction of a centavo.
    direct(owner: @a, with: @b, amount: "0.01")

    assert_empty DirectLedger.new(@a).debts_for_me
  end

  test "an amount that does not divide evenly still reconciles exactly" do
    direct(owner: @a, with: @b, amount: "0.03")

    debts = DirectLedger.new(@a).debts_for_me

    assert_equal 1, debts.size
    assert_equal @b, debts.first.from_user
    assert_equal 1, debts.first.amount_minor
  end
end
