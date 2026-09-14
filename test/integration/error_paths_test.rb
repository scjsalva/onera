# frozen_string_literal: true

require "test_helper"

# What the app does when something is wrong: a stale link, a token that has
# expired, a record somebody else has just voided, an archived group, a form
# posted after the session went away.
class ErrorPathsTest < ActionDispatch::IntegrationTest
  setup do
    @john = create_user(name: "John", username: "johnerr", email: "johnerr@example.com")
    @alice = create_user(name: "Alice", username: "aliceerr", email: "aliceerr@example.com")
    @group = create_group(name: "Trip", members: [ @john, @alice ], creator: @john)
    sign_in_as(@john)
  end

  test "a record that has gone says so instead of erroring" do
    get group_path(id: 999_999)
    assert_redirected_to root_path
    follow_redirect!
    # The flash goes through a Vue element, so the apostrophe arrives escaped.
    assert_match(/isn(&#39;|')t available/i, response.body)
  end

  test "a group somebody else owns is not reachable" do
    other = create_group(name: "Theirs", members: [ @alice ], creator: @alice)

    get group_path(other)
    assert_redirected_to root_path
    follow_redirect!
    refute_match "Theirs", response.body
  end

  test "an expense voided while the form was open does not double void" do
    expense = add_expense(group: @group, actor: @john, amount: "500",
                          payers: [ { user_id: @john.id, amount: "500" } ],
                          participants: [ { user_id: @john.id }, { user_id: @alice.id } ])
    ExpenseVoider.call(expense:, actor: @john)
    voided_at = expense.reload.voided_at

    delete expense_path(expense)
    assert_response :redirect
    assert_equal voided_at.to_i, expense.reload.voided_at.to_i, "voiding twice moved the timestamp"
  end

  test "an archived group refuses writes and explains why" do
    @group.update!(archived_at: Time.current)

    post expenses_path, params: { expense: {
      group_id: @group.id, description: "Late", amount: "100", currency_code: "PHP",
      spent_on: Date.current.to_s, split_method: "equal",
      payers: [ { user_id: @john.id, amount: "100" } ],
      participants: [ { user_id: @john.id } ]
    } }

    assert_response :redirect
    follow_redirect!
    assert_match(/archived/i, response.body)
    assert_equal 0, @group.expenses.count
  end

  test "an invite token that is not real is turned away kindly" do
    delete destroy_user_session_path

    get signup_path(token: "not-a-real-token")
    assert_response :redirect
    follow_redirect!
    assert_match(/isn(&#39;|')t valid any more/i, response.body)
  end

  test "a form posted without a session lands on sign in, not an error" do
    reset!

    post expenses_path, params: { expense: { description: "Ghost", amount: "10" } }
    assert_redirected_to new_user_session_path
  end

  # A fresh database has no exchange rates at all, so a group with a foreign
  # expense in it is the ordinary day-one state. Settle up used to raise
  # "no exchange rate available for JPY -> PHP" and return a 500.
  test "a settle up with no rate on file loads and asks for one" do
    add_expense(group: @group, actor: @john, amount: "5000", currency_code: "JPY",
                payers: [ { user_id: @john.id, amount: "5000" } ],
                participants: [ { user_id: @john.id }, { user_id: @alice.id } ])
    ExchangeRate.delete_all

    get group_settle_up_path(@group)
    assert_response :success
    assert_match "JPY", response.body

    consolidation = BalanceCalculator.new(@group.reload).consolidated(php)
    assert_equal [ "JPY" ], consolidation.missing_rates.map(&:code)
    refute consolidation.convertible?
    assert_empty consolidation.entries, "consolidated a group it had no rate for"
    assert_empty consolidation.suggested_transfers
  end

  test "a rate typed in by hand makes the same group convertible" do
    add_expense(group: @group, actor: @john, amount: "5000", currency_code: "JPY",
                payers: [ { user_id: @john.id, amount: "5000" } ],
                participants: [ { user_id: @john.id }, { user_id: @alice.id } ])
    ExchangeRate.delete_all

    consolidation = BalanceCalculator.new(@group).consolidated(php, rates: { "JPY" => "0.42" })
    assert consolidation.convertible?
    assert_empty consolidation.missing_rates
    assert_equal 2, consolidation.entries.size
    assert_equal 0, consolidation.entries.sum(&:net_minor), "converted balances did not sum to zero"
  end

  # There is no server-rendered expense form to re-render, so a rejected write
  # comes back as the page you were on plus the reason.
  test "an expense with no participants is refused with a sentence, not a crash" do
    post expenses_path, params: { expense: {
      group_id: @group.id, description: "Nobody", amount: "100", currency_code: "PHP",
      spent_on: Date.current.to_s, split_method: "equal",
      payers: [ { user_id: @john.id, amount: "100" } ],
      participants: []
    } }

    assert_response :redirect
    follow_redirect!
    assert_match(/sharing this expense/i, response.body)
    assert_equal 0, @group.expenses.count
  end

  # The same missing-rate hole, one layer up: Insights folds every currency into
  # yours to draw its bars, and used to raise doing it.
  test "every page still renders when the rate table is empty" do
    add_expense(group: @group, actor: @john, amount: "5000", currency_code: "JPY",
                payers: [ { user_id: @john.id, amount: "5000" } ],
                participants: [ { user_id: @john.id }, { user_id: @alice.id } ])
    ExchangeRate.delete_all

    %w[/ /insights /balances /groups /expenses /activity].each do |path|
      get path
      assert_response :success, "#{path} broke with no exchange rates on file"
    end

    get group_path(@group)
    assert_response :success
  end

  test "insights say what they had to leave out rather than counting it as nothing" do
    add_expense(group: @group, actor: @john, amount: "5000", currency_code: "JPY",
                payers: [ { user_id: @john.id, amount: "5000" } ],
                participants: [ { user_id: @john.id }, { user_id: @alice.id } ])
    add_expense(group: @group, actor: @john, amount: "1000",
                payers: [ { user_id: @john.id, amount: "1000" } ],
                participants: [ { user_id: @john.id }, { user_id: @alice.id } ])
    ExchangeRate.delete_all

    dashboard = DashboardCalculator.new(@john.reload)
    by_category = dashboard.spend_by_category

    assert_equal 100_000, by_category.sum { |(_, total)| total.minor },
                 "the peso expense should still be counted in full"
    assert_equal [ "JPY" ], dashboard.unconvertible.to_a

    get insights_path
    assert_response :success
    assert_match(/Leaves out JPY/, response.body)
  end

  private

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
    get "/"
  end
end
