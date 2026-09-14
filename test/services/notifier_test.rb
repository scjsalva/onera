# frozen_string_literal: true

require "test_helper"

class NotifierTest < ActiveSupport::TestCase
  setup do
    @john = create_user(name: "John", username: "johnn")
    @alice = create_user(name: "Alice", username: "alicen")
    @bob = create_user(name: "Bob", username: "bobn")
    @group = create_group(members: [ @john, @alice, @bob ], creator: @john)
  end

  test "people sharing an expense are told, and the author is not" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    assert_equal 0, @john.notifications.count
    assert_equal 1, @alice.notifications.where(kind: "expense.added").count
    assert_equal 1, @bob.notifications.where(kind: "expense.added").count
  end

  test "someone not on the expense is left alone" do
    add_expense(group: @group, actor: @john, amount: "500",
                payers: [ { user_id: @john.id, amount: "500" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    assert_equal 0, @bob.notifications.count
  end

  test "the notification says what it means for you" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    assert_match(/your share is ₱300\.00/i, @alice.notifications.first.body)
  end

  test "a personal expense notifies nobody" do
    assert_no_difference -> { Notification.count } do
      ExpenseCreator.call(owner: @john, actor: @john, params: {
        description: "Coffee", currency_code: "PHP", amount: "150", spent_on: Date.current
      })
    end
  end

  test "the person paid is told, and the payer is not" do
    SettlementCreator.call(group: @group, actor: @alice, params: {
      payer_id: @alice.id, recipient_id: @john.id, currency_code: "PHP",
      amount: "300", settled_on: Date.current
    })

    assert_equal 1, @john.notifications.where(kind: "settlement.received").count
    assert_equal 0, @alice.notifications.count
  end

  test "recording a payment on someone's behalf tells both parties" do
    SettlementCreator.call(group: @group, actor: @bob, params: {
      payer_id: @alice.id, recipient_id: @john.id, currency_code: "PHP",
      amount: "300", settled_on: Date.current
    })

    assert_equal 1, @john.notifications.where(kind: "settlement.received").count
    assert_equal 1, @alice.notifications.where(kind: "settlement.recorded").count
  end

  test "editing and voiding both notify the people affected" do
    expense = add_expense(group: @group, actor: @john, amount: "900",
                          payers: [ { user_id: @john.id, amount: "900" } ],
                          participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    ExpenseUpdater.call(expense:, actor: @john, params: {
      description: "Changed", currency_code: "PHP", amount: "800", spent_on: Date.current,
      split_method: "equal",
      payers: [ { user_id: @john.id, amount: "800" } ],
      participants: [ @john, @alice ].map { |u| { user_id: u.id } }
    })
    ExpenseVoider.call(expense: expense.reload, actor: @john)

    assert_equal 1, @alice.notifications.where(kind: "expense.edited").count
    assert_equal 1, @alice.notifications.where(kind: "expense.voided").count
  end

  test "locking rates tells the whole group" do
    add_expense(group: @group, actor: @john, amount: "1000", currency_code: "JPY",
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    RateLocker.call(group: @group, actor: @john, rates: { "JPY" => "0.39" })

    assert_equal 1, @alice.notifications.where(kind: "rates.locked").count
    assert_equal 1, @bob.notifications.where(kind: "rates.locked").count
  end

  test "a closed account is not notified" do
    UserAnonymizer.call(user: @bob)

    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice, @bob ].map { |u| { user_id: u.id } })

    assert_equal 0, @bob.reload.notifications.count
  end

  test "notifications start unread and can be marked read" do
    add_expense(group: @group, actor: @john, amount: "900",
                payers: [ { user_id: @john.id, amount: "900" } ],
                participants: [ @john, @alice ].map { |u| { user_id: u.id } })

    notification = @alice.notifications.first

    assert_equal 1, @alice.notifications.unread.count
    notification.mark_read!
    assert notification.reload.read?
    assert_equal 0, @alice.notifications.unread.count
  end

  test "marking read twice does not change the timestamp" do
    Notifier.deliver(user: @alice, kind: "expense.added", title: "x")
    notification = @alice.notifications.first
    notification.mark_read!
    first = notification.reload.read_at

    notification.mark_read!

    assert_equal first, notification.reload.read_at
  end
end
