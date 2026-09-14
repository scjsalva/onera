# frozen_string_literal: true

require "test_helper"

# What one person can reach of another person's money.
class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user(name: "Owner", username: "owner", email: "owner@example.com")
    @member = create_user(name: "Member", username: "member", email: "member@example.com")
    @stranger = create_user(name: "Stranger", username: "stranger", email: "stranger@example.com")

    @group = create_group(name: "Private Trip", members: [ @owner, @member ], creator: @owner)
    @expense = add_expense(group: @group, actor: @owner, amount: "1000",
                           payers: [ { user_id: @owner.id, amount: "1000" } ],
                           participants: [ @owner, @member ].map { |u| { user_id: u.id } })
    @personal = ExpenseCreator.call(owner: @owner, actor: @owner, params: {
      description: "Private coffee", currency_code: "PHP", amount: "150", spent_on: Date.current
    }).expense
  end

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
  end

  test "a stranger cannot open the group" do
    sign_in_as @stranger
    get "/groups/#{@group.id}"

    assert_redirected_to root_path
  end

  test "a stranger cannot open any of the group's tabs" do
    sign_in_as @stranger

    %w[expenses balances activity memberships settlements settle_up].each do |tab|
      get "/groups/#{@group.id}/#{tab}"
      assert_redirected_to root_path, "#{tab} should be out of reach"
    end
  end

  test "a stranger cannot see the group's name anywhere" do
    sign_in_as @stranger

    %w[/ /groups /expenses /balances /activity /people].each do |path|
      get path
      follow_redirect! while response.redirect?
      refute_includes response.body, "Private Trip", "#{path} leaked the group name"
    end
  end

  test "a stranger cannot open an expense from the group" do
    sign_in_as @stranger
    get "/expenses/#{@expense.id}"

    assert_redirected_to root_path
  end

  test "a stranger cannot open someone else's personal expense" do
    sign_in_as @stranger
    get "/expenses/#{@personal.id}"

    assert_redirected_to root_path
  end

  test "a stranger cannot add an expense to a group they are not in" do
    sign_in_as @stranger

    assert_no_difference -> { @group.expenses.count } do
      post "/expenses", params: { expense: {
        group_id: @group.id, description: "Sneaky", amount: "50", currency_code: "PHP",
        spent_on: Date.current.to_s, split_method: "equal",
        payers: { "0" => { user_id: @owner.id, amount: "50" } },
        participants: { "0" => { user_id: @owner.id } }
      } }
    end
  end

  test "a stranger cannot void someone else's expense" do
    sign_in_as @stranger
    patch "/expenses/#{@expense.id}/void"

    assert_redirected_to root_path
    refute @expense.reload.voided?
  end

  test "a stranger cannot record a settlement in the group" do
    sign_in_as @stranger

    assert_no_difference -> { Settlement.count } do
      post "/groups/#{@group.id}/settlements", params: { settlement: {
        payer_id: @member.id, recipient_id: @owner.id, amount: "100",
        currency_code: "PHP", settled_on: Date.current.to_s
      } }
    end
  end

  test "a stranger cannot lock the group's rates" do
    sign_in_as @stranger
    post "/groups/#{@group.id}/settle_up", params: { currency: "PHP", rates: { "JPY" => "1" } }

    assert_redirected_to root_path
  end

  test "a member can do all of it" do
    sign_in_as @member
    get "/groups/#{@group.id}"

    assert_response :success
    get "/expenses/#{@expense.id}"
    assert_response :success
  end

  test "a member still cannot open the owner's personal expense" do
    sign_in_as @member
    get "/expenses/#{@personal.id}"

    assert_redirected_to root_path
  end

  test "notifications belong to one person only" do
    sign_in_as @stranger
    other = Notification.create!(user: @owner, kind: "expense.added", title: "Private")

    patch "/notifications/#{other.id}"

    assert_redirected_to root_path
    refute other.reload.read?
  end

  test "signing out clears access" do
    sign_in_as @member
    delete "/sign-out"
    get "/groups/#{@group.id}"

    assert_redirected_to "/sign-in"
  end
end
