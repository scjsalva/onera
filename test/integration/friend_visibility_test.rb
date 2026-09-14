# frozen_string_literal: true

require "test_helper"

# The rule in full: a group lets two strangers split a cost inside it, and
# changes nothing outside it.
class FriendVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @a = create_user(name: "Ann", username: "annv")
    @b = create_user(name: "Ben", username: "benv")
    @c = create_user(name: "Cal", username: "calv")

    Friendship.request(from: @a, to: @b).accept!
    Friendship.request(from: @a, to: @c).accept!
    # Ben and Cal have never added each other.

    @group = create_group(name: "Shared", members: [ @a, @b, @c ], creator: @a)
  end

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
    get "/"
    patch "/email", params: { skip: "Not now" } if response.redirect?
  end

  def direct_expense(owner:, with:)
    ExpenseCreator.call(owner:, actor: owner, params: {
      description: "Direct", currency_code: "PHP", amount: "500", spent_on: Date.current,
      split_method: "equal",
      payers: [ { user_id: owner.id, amount: "500" } ],
      participants: [ { user_id: owner.id }, { user_id: with.id } ]
    })
  end

  test "you can split directly with someone you've added" do
    assert direct_expense(owner: @a, with: @b).success?
    assert direct_expense(owner: @b, with: @a).success?
  end

  test "you cannot split directly with someone you haven't, even in a shared group" do
    result = direct_expense(owner: @b, with: @c)

    refute result.success?
    assert_match(/people you've added/, result.errors.join)
  end

  test "a group expense may involve anyone in the group" do
    result = ExpenseCreator.call(group: @group, actor: @b, params: {
      description: "Group dinner", currency_code: "PHP", amount: "900", spent_on: Date.current,
      split_method: "equal",
      payers: [ { user_id: @b.id, amount: "900" } ],
      participants: [ @a, @b, @c ].map { |u| { user_id: u.id } }
    })

    assert result.success?, result.errors.join
  end

  test "the people list shows only the ones you've added" do
    sign_in_as @b
    get "/people"

    assert_includes response.body, "Ann"
    refute_includes response.body, "Cal"
  end

  test "you can only add your own people to a group" do
    sign_in_as @b
    other_group = create_group(name: "Ben's", members: [ @b ], creator: @b)

    assert_no_difference -> { other_group.group_memberships.count } do
      post "/groups/#{other_group.id}/memberships", params: { user_ids: [ @c.id ] }
    end
  end

  test "a group member you have not added is still addable by someone who has" do
    sign_in_as @a
    other_group = create_group(name: "Ann's", members: [ @a ], creator: @a)

    assert_difference -> { other_group.group_memberships.count }, 1 do
      post "/groups/#{other_group.id}/memberships", params: { user_ids: [ @c.id ] }
    end
  end

  test "settling directly needs a connection" do
    connected = Settlement.new(payer: @a, recipient: @b, currency_code: "PHP",
                               base_currency_code: "PHP", amount_minor: 100,
                               base_amount_minor: 100, settled_on: Date.current)
    strangers = Settlement.new(payer: @b, recipient: @c, currency_code: "PHP",
                               base_currency_code: "PHP", amount_minor: 100,
                               base_amount_minor: 100, settled_on: Date.current)

    assert connected.valid?
    refute strangers.valid?
  end

  test "a direct debt shows on both dashboards and nowhere else" do
    direct_expense(owner: @a, with: @b)

    assert_equal 25_000, DashboardCalculator.new(@a).counterparties.first.net_minor
    assert_equal(-25_000, DashboardCalculator.new(@b).counterparties.first.net_minor)
    assert_empty DashboardCalculator.new(@c).counterparties
  end

  test "a direct expense is invisible to everyone else" do
    result = direct_expense(owner: @a, with: @b)
    sign_in_as @c

    get "/expenses/#{result.expense.id}"

    assert_redirected_to root_path
  end
end
