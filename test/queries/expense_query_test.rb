# frozen_string_literal: true

require "test_helper"

class ExpenseQueryTest < ActiveSupport::TestCase
  setup do
    @john = create_user(name: "John", username: "johnq")
    @alice = create_user(name: "Alice", username: "aliceq")
    @group = create_group(name: "Japan", members: [ @john, @alice ], creator: @john)
    @food = Category.find_by(slug: "food")
    @transport = Category.find_by(slug: "transport")

    @dinner = add_expense(group: @group, actor: @john, description: "Dinner in Shibuya",
                          amount: "1000", category_id: @food.id, spent_on: Date.current,
                          payers: [ { user_id: @john.id, amount: "1000" } ],
                          participants: [ @john, @alice ].map { |u| { user_id: u.id } })
    @train = add_expense(group: @group, actor: @alice, description: "Shinkansen",
                         amount: "5000", currency_code: "JPY", category_id: @transport.id,
                         spent_on: 40.days.ago.to_date, notes: "Reserved seats",
                         payers: [ { user_id: @alice.id, amount: "5000" } ],
                         participants: [ @john, @alice ].map { |u| { user_id: u.id } })
    @personal = ExpenseCreator.call(owner: @john, actor: @john, params: {
      description: "Solo coffee", currency_code: "PHP", amount: "150", spent_on: Date.current
    }).expense
  end

  def results(params) = ExpenseQuery.new(Expense.all, filter: ExpenseFilter.new(params)).call.to_a

  test "no filters returns everything active" do
    assert_equal 3, results({}).size
  end

  test "search matches a description" do
    assert_equal [ @dinner ], results(q: "shibuya")
  end

  test "search is case-insensitive" do
    assert_equal [ @dinner ], results(q: "SHIBUYA")
  end

  test "search matches notes" do
    assert_equal [ @train ], results(q: "reserved")
  end

  test "search matches a category name" do
    assert_equal [ @train ], results(q: "transport")
  end

  test "search matches a group name" do
    assert_includes results(q: "japan"), @dinner
    refute_includes results(q: "japan"), @personal
  end

  test "search matches a person's name" do
    assert_includes results(q: "Alice"), @train
  end

  test "search finds nothing for a term nobody used" do
    assert_empty results(q: "helicopter")
  end

  test "a percent sign in the search is treated as text, not a wildcard" do
    assert_empty results(q: "%")
  end

  test "filtering by category narrows to it" do
    assert_equal [ @dinner ], results(category_id: @food.id)
  end

  test "filtering by currency narrows to it" do
    assert_equal [ @train ], results(currency_code: "JPY")
  end

  test "filtering by payer finds who actually paid" do
    assert_equal [ @train ], results(payer_id: @alice.id)
  end

  test "personal filters to expenses with no group" do
    assert_equal [ @personal ], results(group_id: "personal")
  end

  test "filtering by a group id excludes personal ones" do
    ids = results(group_id: @group.id).map(&:id)

    assert_includes ids, @dinner.id
    refute_includes ids, @personal.id
  end

  test "this month excludes something from last month" do
    ids = results(period: "month").map(&:id)

    assert_includes ids, @dinner.id
    refute_includes ids, @train.id
  end

  test "a custom range works both ways round" do
    ids = results(period: "custom", from: 60.days.ago.to_date.to_s, to: 30.days.ago.to_date.to_s).map(&:id)

    assert_equal [ @train.id ], ids
  end

  test "voided expenses are hidden by default and findable on request" do
    ExpenseVoider.call(expense: @dinner, actor: @john)

    refute_includes results({}).map(&:id), @dinner.id
    assert_includes results(status: "voided").map(&:id), @dinner.id
    assert_includes results(status: "all").map(&:id), @dinner.id
  end

  test "filters combine rather than replace each other" do
    assert_empty results(q: "shibuya", category_id: @transport.id)
    assert_equal [ @dinner ], results(q: "shibuya", category_id: @food.id)
  end

  test "an unrecognised period is ignored rather than blowing up" do
    assert_equal 3, results(period: "fortnight").size
  end

  test "a malformed date is ignored rather than blowing up" do
    assert_equal 3, results(period: "custom", from: "not-a-date").size
  end

  test "amount bounds respect the currency's decimal places" do
    yen_group = create_group(name: "Tokyo", currency: "JPY", members: [ @john ], creator: @john)
    add_expense(group: yen_group, actor: @john, description: "Ramen", amount: "1200",
                currency_code: "JPY",
                payers: [ { user_id: @john.id, amount: "1200" } ],
                participants: [ { user_id: @john.id } ])

    ramen = yen_group.expenses.first

    # ¥1,200 is 1200 minor units, not 120000. Comparing with a flat times-100
    # would have treated it as ¥120,000 and put it above every sane maximum.
    assert_includes results(group_id: yen_group.id, min_amount: "1000").map(&:id), ramen.id
    assert_includes results(group_id: yen_group.id, max_amount: "1500").map(&:id), ramen.id
    assert_empty results(group_id: yen_group.id, min_amount: "2000")
    assert_empty results(group_id: yen_group.id, max_amount: "1000")
  end

  test "amount bounds still work for two-decimal currencies" do
    assert_includes results(min_amount: "500").map(&:id), @train.id
    refute_includes results(max_amount: "200").map(&:id), @dinner.id
    assert_includes results(max_amount: "200").map(&:id), @personal.id
  end

  test "everything happens in SQL rather than in Ruby" do
    sql = ExpenseQuery.new(Expense.all, filter: ExpenseFilter.new(q: "dinner")).call.to_sql

    assert_match(/ILIKE/, sql)
    assert_match(/EXISTS/, sql)
  end
end
