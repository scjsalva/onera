# frozen_string_literal: true

require "test_helper"

# The write paths as the browser actually posts them, including the nested
# index-keyed parameters Rails builds from a form.
class ExpenseFlowTest < ActionDispatch::IntegrationTest
  setup do
    @john = create_user(name: "John", username: "johnflow", email: "johnflow@example.com")
    @alice = create_user(name: "Alice", username: "aliceflow", email: "aliceflow@example.com")
    @group = create_group(name: "Trip", members: [ @john, @alice ], creator: @john)
    sign_in_as @john
  end

  # A new account has no expenses and no filters, and telling them nothing
  # matched their filters is the first thing they would read.
  test "an empty list says what is actually true" do
    get expenses_path
    assert_match "No expenses yet", response.body
    refute_match "match these filters", response.body

    get expenses_path(period: "week")
    assert_match "match these filters", response.body
    assert_match "Clear filters", response.body
  end

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
    get "/"
    patch "/email", params: { skip: "Not now" } if response.redirect?
  end

  def post_expense(**overrides)
    post "/expenses", params: { expense: {
      group_id: @group.id, description: "Dinner", amount: "900", currency_code: "PHP",
      spent_on: Date.current.to_s, split_method: "equal",
      payers: { "0" => { user_id: @john.id, amount: "900" } },
      participants: { "0" => { user_id: @john.id }, "1" => { user_id: @alice.id } }
    }.merge(overrides) }
  end

  test "a form-shaped post creates the expense" do
    assert_difference -> { Expense.count }, 1 do
      post_expense
    end

    expense = Expense.last

    assert_equal 90_000, expense.amount_minor
    assert_equal [ 45_000, 45_000 ], expense.expense_splits.pluck(:amount_minor)
  end

  test "nested parameters arrive as an index-keyed hash, not an array" do
    post_expense(payers: { "0" => { user_id: @john.id, amount: "500" },
                           "1" => { user_id: @alice.id, amount: "400" } })

    assert_equal 2, Expense.last.expense_payers.count
  end

  test "a mismatched payer total is refused and nothing is stored" do
    assert_no_difference -> { Expense.count } do
      post_expense(payers: { "0" => { user_id: @john.id, amount: "100" } })
    end
  end

  test "an expense with no group belongs to the person posting it" do
    post "/expenses", params: { expense: {
      group_id: "", description: "Solo lunch", amount: "250",
      currency_code: "PHP", spent_on: Date.current.to_s
    } }

    expense = Expense.last

    assert expense.personal?
    assert_equal @john, expense.owner
  end

  test "voiding leaves the record and drops it from the balances" do
    post_expense
    expense = Expense.last

    patch "/expenses/#{expense.id}/void", params: { reason: "Wrong group" }

    assert expense.reload.voided?
    assert_equal "Wrong group", expense.void_reason
    assert_equal 0, BalanceCalculator.new(@group).total_spend(php).minor
  end

  test "a voided expense can be restored" do
    post_expense
    expense = Expense.last
    patch "/expenses/#{expense.id}/void"

    patch "/expenses/#{expense.id}/restore"

    assert expense.reload.active?
  end

  test "deleting is refused - expenses are voided instead" do
    post_expense
    expense = Expense.last

    assert_no_difference -> { Expense.count } do
      delete "/expenses/#{expense.id}"
    end
  end

  test "a settlement clears what it pays" do
    post_expense

    post "/groups/#{@group.id}/settlements", params: { settlement: {
      payer_id: @alice.id, recipient_id: @john.id, amount: "450",
      currency_code: "PHP", settled_on: Date.current.to_s
    } }

    assert_equal 0, BalanceCalculator.new(@group).standing_for(@alice.id).position_in("PHP").net_minor
  end

  test "recording a payment on someone's behalf tells them, not yourself" do
    post_expense

    post "/groups/#{@group.id}/settlements", params: { settlement: {
      payer_id: @alice.id, recipient_id: @john.id, amount: "450",
      currency_code: "PHP", settled_on: Date.current.to_s
    } }

    # John recorded it and is the recipient, so he needs no telling. Alice had
    # a payment logged against her name and does.
    assert_empty @john.notifications.where("kind LIKE 'settlement%'")
    assert @alice.notifications.where(kind: "settlement.recorded").exists?
  end

  test "a settlement to yourself is refused" do
    assert_no_difference -> { Settlement.count } do
      post "/groups/#{@group.id}/settlements", params: { settlement: {
        payer_id: @john.id, recipient_id: @john.id, amount: "100",
        currency_code: "PHP", settled_on: Date.current.to_s
      } }
    end
  end

  test "a settlement of zero is refused" do
    assert_no_difference -> { Settlement.count } do
      post "/groups/#{@group.id}/settlements", params: { settlement: {
        payer_id: @alice.id, recipient_id: @john.id, amount: "0",
        currency_code: "PHP", settled_on: Date.current.to_s
      } }
    end
  end

  test "the split preview matches what saving actually stores" do
    post "/api/split_previews", params: {
      group_id: @group.id, amount: "1000", currency_code: "PHP", split_method: "shares",
      participants: { "0" => { user_id: @john.id, split_value: "2" },
                      "1" => { user_id: @alice.id, split_value: "1" } }
    }, as: :json

    previewed = response.parsed_body["splits"].map { |s| s["minor"] }

    post_expense(amount: "1000", split_method: "shares",
                 payers: { "0" => { user_id: @john.id, amount: "1000" } },
                 participants: { "0" => { user_id: @john.id, split_value: "2" },
                                 "1" => { user_id: @alice.id, split_value: "1" } })

    assert_equal previewed, Expense.last.expense_splits.pluck(:amount_minor)
  end

  test "removing someone with money in the group is refused" do
    post_expense
    membership = @group.group_memberships.find_by(user: @alice)

    assert_no_difference -> { GroupMembership.count } do
      delete "/groups/#{@group.id}/memberships/#{membership.id}"
    end
  end

  test "a group with records is archived rather than destroyed" do
    post_expense

    delete "/groups/#{@group.id}"

    assert Group.exists?(@group.id)
    assert @group.reload.archived?
  end
end
