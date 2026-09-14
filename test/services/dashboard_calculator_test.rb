# frozen_string_literal: true

require "test_helper"

class DashboardCalculatorTest < ActiveSupport::TestCase
  setup do
    @john = create_user(name: "John", username: "johnd")
    @alice = create_user(name: "Alice", username: "aliced")
    @bob = create_user(name: "Bob", username: "bobd")

    @trip = create_group(name: "Trip", members: [ @john, @alice ], creator: @john)
    @flat = create_group(name: "Flat", members: [ @john, @bob ], creator: @john)
    @theirs = create_group(name: "Not Mine", members: [ @alice, @bob ], creator: @alice)
  end

  def dashboard(user = @john) = DashboardCalculator.new(user)

  test "only the groups you belong to are counted" do
    names = dashboard.groups.map(&:name)

    assert_includes names, "Trip"
    assert_includes names, "Flat"
    refute_includes names, "Not Mine"
  end

  test "a group you are not in cannot reach your totals" do
    add_expense(group: @theirs, actor: @alice, amount: "5000",
                payers: [ { user_id: @alice.id, amount: "5000" } ],
                participants: [ @alice, @bob ].map { |u| { user_id: u.id } })

    assert_equal 0, dashboard.total_spend.minor
  end

  test "spending is summed across your groups" do
    add_expense(group: @trip, actor: @john, amount: "1000",
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })
    add_expense(group: @flat, actor: @john, amount: "500",
                payers: [ { user_id: @john.id, amount: "500" } ],
                participants: [ @john, @bob ].map { |u| { user_id: u.id } })

    assert_equal 150_000, dashboard.total_spend.minor
    assert_equal 150_000, dashboard.total_paid.minor
    assert_equal 75_000, dashboard.total_share.minor
  end

  test "personal spending counts towards your own totals" do
    ExpenseCreator.call(owner: @john, actor: @john, params: {
      description: "Coffee", currency_code: "PHP", amount: "250", spent_on: Date.current
    })

    assert_equal 25_000, dashboard.personal_spend.minor
    assert_equal 25_000, dashboard.total_spend.minor
  end

  test "someone else's personal spending is invisible to you" do
    ExpenseCreator.call(owner: @alice, actor: @alice, params: {
      description: "Theirs", currency_code: "PHP", amount: "999", spent_on: Date.current
    })

    assert_equal 0, dashboard.personal_spend.minor
    assert_equal 0, dashboard.total_spend.minor
  end

  test "counterparties net across groups into one figure per person" do
    add_expense(group: @trip, actor: @john, amount: "1000",
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })
    add_expense(group: @flat, actor: @bob, amount: "400",
                payers: [ { user_id: @bob.id, amount: "400" } ],
                participants: [ @john, @bob ].map { |u| { user_id: u.id } })

    people = dashboard.counterparties.index_by { |c| c.user.name }

    assert_equal 50_000, people["Alice"].net_minor
    assert_equal(-20_000, people["Bob"].net_minor)
  end

  test "the per-group breakdown adds up to the netted figure" do
    add_expense(group: @trip, actor: @john, amount: "1000",
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    counterparty = dashboard.counterparties.first

    assert_equal counterparty.net_minor, counterparty.breakdown.sum(&:net_minor)
  end

  test "owed and owing are reported separately and net correctly" do
    add_expense(group: @trip, actor: @john, amount: "1000",
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })
    add_expense(group: @flat, actor: @bob, amount: "400",
                payers: [ { user_id: @bob.id, amount: "400" } ],
                participants: [ @john, @bob ].map { |u| { user_id: u.id } })

    assert_equal 50_000, dashboard.owed_to_you.minor
    assert_equal 20_000, dashboard.you_owe.minor
    assert_equal 30_000, dashboard.net_balance.minor
  end

  test "someone with nothing has a clean zeroed dashboard" do
    quiet = create_user(name: "Quiet", username: "quietd")
    board = DashboardCalculator.new(quiet)

    assert_equal 0, board.total_spend.minor
    assert_equal 0, board.net_balance.minor
    assert_empty board.counterparties
    assert_empty board.groups
    refute board.estimated?
  end

  test "totals are shown in the viewer's own currency" do
    @john.update!(preferred_currency_code: "USD")

    assert_equal "USD", dashboard.display_currency.code
    assert_equal "USD", dashboard.total_spend.currency.code
  end

  test "a mixed-currency group marks the dashboard as estimated" do
    add_expense(group: @trip, actor: @john, amount: "1000", currency_code: "JPY",
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    assert dashboard.estimated?
  end

  test "voided expenses drop out of every total" do
    expense = add_expense(group: @trip, actor: @john, amount: "1000",
                          payers: [ { user_id: @john.id, amount: "1000" } ],
                          participants: [ @john, @alice ].map { |u| { user_id: u.id } })
    ExpenseVoider.call(expense:, actor: @john)

    assert_equal 0, dashboard.total_spend.minor
    assert_empty dashboard.counterparties
  end

  test "spend by category folds mixed currencies into one" do
    food = Category.find_by(slug: "food")
    add_expense(group: @trip, actor: @john, amount: "1000", category_id: food.id,
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    by_category = dashboard.spend_by_category.to_h

    assert_equal 100_000, by_category["Food"].minor
  end

  test "spend by month always returns the full window, gaps included" do
    assert_equal 6, dashboard.spend_by_month(months: 6).size
  end
end
