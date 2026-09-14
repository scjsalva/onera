# frozen_string_literal: true

require "test_helper"

class TimelineTest < ActiveSupport::TestCase
  setup do
    @a = create_user(name: "Ann", username: "annt")
    @b = create_user(name: "Ben", username: "bent")
    @group = create_group(name: "Trip", members: [ @a, @b ], creator: @a)

    @old = add_expense(group: @group, actor: @a, description: "Older", amount: "300",
                       spent_on: 5.days.ago.to_date,
                       payers: [ { user_id: @a.id, amount: "300" } ],
                       participants: [ @a, @b ].map { |u| { user_id: u.id } })
    @new = add_expense(group: @group, actor: @a, description: "Newer", amount: "100",
                       spent_on: 1.day.ago.to_date,
                       payers: [ { user_id: @a.id, amount: "100" } ],
                       participants: [ @a, @b ].map { |u| { user_id: u.id } })
    @settlement = SettlementCreator.call(group: @group, actor: @b, params: {
      payer_id: @b.id, recipient_id: @a.id, currency_code: "PHP",
      amount: "50", settled_on: 3.days.ago.to_date
    }).settlement
  end

  def timeline(include_settlements: true)
    Timeline.new(expenses: @group.expenses.active.recent_first,
                 settlements: @group.settlements.active.recent_first,
                 include_settlements:)
  end

  test "expenses and settlements are interleaved newest first" do
    records = timeline.entries.map(&:record)

    assert_equal [ @new, @settlement, @old ], records
  end

  test "each entry knows which kind it is" do
    entries = timeline.entries

    assert entries.first.expense?
    assert entries.second.settlement?
  end

  test "settlements can be left out" do
    assert_equal [ @new, @old ], timeline(include_settlements: false).entries.map(&:record)
  end

  test "a filter that describes an expense hides settlements" do
    refute Timeline.settlements_relevant?(ExpenseFilter.new(category_id: 1))
    refute Timeline.settlements_relevant?(ExpenseFilter.new(currency_code: "JPY"))
    refute Timeline.settlements_relevant?(ExpenseFilter.new(q: "dinner"))
    refute Timeline.settlements_relevant?(ExpenseFilter.new(status: "voided"))
    refute Timeline.settlements_relevant?(ExpenseFilter.new(min_amount: "10"))
  end

  test "a date filter keeps them, since a payment has a date too" do
    assert Timeline.settlements_relevant?(ExpenseFilter.new(period: "month"))
    assert Timeline.settlements_relevant?(ExpenseFilter.new)
  end

  test "an empty timeline reports itself as empty" do
    empty = Timeline.new(expenses: Expense.none, settlements: Settlement.none)

    refute empty.any?
    assert_empty empty.entries
  end
end
