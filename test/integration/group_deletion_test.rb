# frozen_string_literal: true

require "test_helper"

# Deleting an empty group used to fail at the database, because a table nobody
# had thought about still pointed at it. This walks every table with a foreign
# key to groups, gives the group one row in each, and then deletes it.
class GroupDeletionTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user(name: "John Salva", username: "scjsalva", email: "john@example.com")
    @friend = create_user(name: "Christian Nasayao", username: "cnasayao")
    @group = create_group(name: "Baguio", members: [ @owner, @friend ], creator: @owner)
    sign_in_as(@owner)
  end

  test "an empty group can be deleted however many tables point at it" do
    Invitation.create!(group: @group, created_by: @owner, token: SecureRandom.hex(16))
    Notifier.added_to_group(@friend, group: @group, actor: @owner)
    ActivityRecorder.record(action: "group.created", summary: "created", group: @group,
                            actor: @owner, subject: @group)

    tables = referencing_tables
    assert_operator tables.size, :>=, 4, "expected several tables to point at groups, found #{tables.inspect}"
    populated = tables.select { |table| rows_for(table).positive? }
    # Guard against the test passing because it populated nothing: invitations
    # is the table that actually blew up, and notifications was next in line.
    assert_includes populated, "invitations"
    assert_includes populated, "notifications"

    assert_difference "Group.count", -1 do
      delete group_path(@group)
    end
    assert_redirected_to groups_path

    populated.each do |table|
      assert_equal 0, rows_for(table), "#{table} still holds rows for the deleted group"
    end
  end

  test "a group with money in it is archived instead, and keeps everything" do
    add_expense(group: @group, actor: @owner, amount: "1000",
                payers: [ { user_id: @owner.id, amount: "1000" } ],
                participants: [ { user_id: @owner.id }, { user_id: @friend.id } ])

    assert_no_difference "Group.count" do
      delete group_path(@group)
    end
    assert @group.reload.archived?
    assert_equal 1, @group.expenses.count
  end

  private

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
    get "/"
  end

  def referencing_tables
    conn = ActiveRecord::Base.connection
    conn.tables.select { |table| conn.foreign_keys(table).any? { |fk| fk.to_table == "groups" } }
  end

  def rows_for(table)
    column = ActiveRecord::Base.connection.foreign_keys(table).find { |fk| fk.to_table == "groups" }.column
    ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM #{table} WHERE #{column} = #{@group.id}"
    ).to_i
  end
end
