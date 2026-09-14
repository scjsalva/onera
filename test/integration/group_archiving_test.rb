# frozen_string_literal: true

require "test_helper"

# Archiving hides a group and freezes it. It never deletes anything, which is
# the whole distinction from the delete beside it.
class GroupArchivingTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user(name: "Owner", username: "archowner")
    @mate = create_user(name: "Mate", username: "archmate")
    Friendship.request(from: @owner, to: @mate).accept!

    @group = create_group(name: "Old Trip", members: [ @owner, @mate ], creator: @owner)
    @expense = add_expense(group: @group, actor: @owner, amount: "900", description: "Dinner",
                           payers: [ { user_id: @owner.id, amount: "900" } ],
                           participants: [ @owner, @mate ].map { |u| { user_id: u.id } })
    sign_in_as @owner
  end

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
    get "/"
    patch "/email", params: { skip: "Not now" } if response.redirect?
  end

  def archive! = patch("/groups/#{@group.id}/archive")

  test "archiving keeps everything" do
    assert_no_difference [ -> { Expense.count }, -> { Group.count }, -> { GroupMembership.count } ] do
      archive!
    end

    assert @group.reload.archived?
  end

  test "an archived group leaves your balances alone" do
    before = DashboardCalculator.new(@owner).owed_to_you.minor
    assert_operator before, :>, 0

    archive!

    assert_equal 0, DashboardCalculator.new(@owner.reload).owed_to_you.minor
    assert_empty DashboardCalculator.new(@owner.reload).groups
  end

  test "but its spending is still part of where your money went" do
    archive!

    spend = DashboardCalculator.new(@owner.reload).spend_by_category.sum { |_, money| money.minor }

    assert_equal 90_000, spend
  end

  test "everyone in the group is told" do
    archive!

    assert @mate.notifications.where(kind: "group.archived").exists?
  end

  test "it is still readable" do
    archive!
    get "/groups/#{@group.id}"

    assert_response :success
    assert_match(/is archived/, response.body)
  end

  test "no new expense can be added to it" do
    archive!

    assert_no_difference -> { Expense.count } do
      post "/expenses", params: { expense: {
        group_id: @group.id, description: "Late", amount: "100", currency_code: "PHP",
        spent_on: Date.current.to_s, split_method: "equal",
        payers: { "0" => { user_id: @owner.id, amount: "100" } },
        participants: { "0" => { user_id: @owner.id } }
      } }
    end
  end

  test "no payment can be recorded in it" do
    archive!

    assert_no_difference -> { Settlement.count } do
      post "/groups/#{@group.id}/settlements", params: { settlement: {
        payer_id: @mate.id, recipient_id: @owner.id, amount: "100",
        currency_code: "PHP", settled_on: Date.current.to_s
      } }
    end
  end

  test "its existing expenses cannot be edited or voided" do
    archive!

    patch "/expenses/#{@expense.id}/void"
    refute @expense.reload.voided?
  end

  test "its people cannot change" do
    archive!
    other = create_user(name: "Third", username: "archthird")
    Friendship.request(from: @owner, to: other).accept!

    assert_no_difference -> { @group.group_memberships.count } do
      post "/groups/#{@group.id}/memberships", params: { user_ids: [ other.id ] }
    end
  end

  test "settling up is refused" do
    archive!
    get "/groups/#{@group.id}/settle_up"

    assert_redirected_to group_path(@group)
  end

  test "reopening puts it back exactly as it was" do
    before = DashboardCalculator.new(@owner).owed_to_you.minor
    archive!
    patch "/groups/#{@group.id}/restore"

    refute @group.reload.archived?
    assert_equal before, DashboardCalculator.new(@owner.reload).owed_to_you.minor
    assert @mate.notifications.where(kind: "group.restored").exists?
  end

  test "archiving twice is refused rather than re-notifying" do
    archive!
    archive!

    assert_equal 1, @mate.notifications.where(kind: "group.archived").count
  end

  test "a group holding money is archived rather than deleted, whatever was clicked" do
    assert_no_difference -> { Group.count } do
      delete "/groups/#{@group.id}"
    end

    assert @group.reload.archived?
  end

  test "an empty group can be deleted outright, invitations and all" do
    empty = create_group(name: "Nothing Here", members: [ @owner ], creator: @owner)
    Invitation.for(group: empty, creator: @owner)
    Notification.create!(user: @owner, group: empty, kind: "group.added", title: "x")

    assert_difference -> { Group.count }, -1 do
      delete "/groups/#{empty.id}"
    end
  end

  test "group details can be edited" do
    patch "/groups/#{@group.id}", params: { group: {
      name: "Renamed Trip", description: "Changed", base_currency_code: "USD"
    } }
    @group.reload

    assert_equal "Renamed Trip", @group.name
    assert_equal "USD", @group.base_currency_code
  end

  test "settings are reachable from the group" do
    get "/groups/#{@group.id}"

    assert_match(%r{/groups/#{@group.id}/edit}, response.body)
  end
end
