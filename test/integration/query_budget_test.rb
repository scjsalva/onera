# frozen_string_literal: true

require "test_helper"

# Every list page used to build one BalanceCalculator per group, each running
# the same eight aggregates against a different group_id, so the query count
# followed the group count: twelve groups meant 170 round trips to draw
# Balances. On a free-tier database a mile from the app server that is the
# difference between a page and a wait.
#
# Twelve groups is more than anyone will really have, which is the point - a
# budget set at a realistic size cannot tell linear growth from a constant.
class QueryBudgetTest < ActionDispatch::IntegrationTest
  GROUPS = 12
  PEOPLE = 8
  EXPENSES_PER_GROUP = 12

  # Room to move, but not room for another per-group query to hide in.
  BUDGETS = {
    "/" => 50,
    "/expenses" => 20,
    "/balances" => 50,
    "/groups" => 10,
    "/people" => 30,
    "/insights" => 50,
    "/activity" => 15,
    "/notifications" => 15
  }.freeze

  setup do
    @people = PEOPLE.times.map { |i| create_user(name: "Person #{i}", username: "qb#{i}", email: "qb#{i}@example.com") }
    @me = @people.first
    @people.drop(1).each { |person| Friendship.create!(requester: @me, addressee: person, status: "accepted") }

    @groups = GROUPS.times.map { |i| create_group(name: "Group #{i}", members: @people, creator: @me) }
    @groups.each { |group| fill(group) }
    sign_in_as(@me)
  end

  test "the pages that list groups do not query per group" do
    over = BUDGETS.filter_map do |path, budget|
      queries = count_queries { get path }
      assert_response :success, "#{path} did not render"

      next if queries.size <= budget

      "#{path}: #{queries.size} queries, budget #{budget}\n    #{repeated(queries)}"
    end

    assert_empty over, "over budget:\n  #{over.join("\n  ")}"
  end

  test "a single group's own pages stay flat too" do
    group = @groups.first

    { "/groups/#{group.id}" => 30,
      "/groups/#{group.id}/memberships" => 30,
      "/groups/#{group.id}/settle_up" => 30 }.each do |path, budget|
      queries = count_queries { get path }
      assert_response :success, "#{path} did not render"
      assert_operator queries.size, :<=, budget,
                      "#{path} took #{queries.size} queries\n    #{repeated(queries)}"
    end
  end

  private

  # Cache hits are excluded on purpose: they never reach the database, and the
  # cost this guards against is the round trip.
  def count_queries
    queries = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      next if payload[:cached] || payload[:name].to_s.in?(%w[SCHEMA TRANSACTION])

      queries << payload[:sql]
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  def repeated(queries)
    queries.group_by { |sql| sql.gsub(/\d+/, "N") }
           .transform_values(&:size)
           .sort_by { |_, count| -count }
           .first(3)
           .map { |sql, count| "#{count}x #{sql[0, 120]}" }
           .join("\n    ")
  end

  def fill(group)
    EXPENSES_PER_GROUP.times do |n|
      payer = @people[n % @people.size]
      add_expense(group:, actor: payer, amount: "#{100 + n}0",
                  payers: [ { user_id: payer.id, amount: "#{100 + n}0" } ],
                  participants: @people.map { |person| { user_id: person.id } })
    end

    SettlementCreator.call(group:, actor: @people[1], params: {
      payer_id: @people[1].id, recipient_id: @me.id,
      amount: "50", currency_code: "PHP", paid_on: Date.current
    })
  end

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
    get "/"
  end
end
