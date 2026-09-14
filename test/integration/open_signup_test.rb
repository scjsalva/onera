# frozen_string_literal: true

require "test_helper"

# Accounts are invite-only and an invitation needs a member to send it, so an
# empty deployment has no way in at all. The first person walks through the
# front door; after that the door is not there, and not because of a setting or
# a date - the condition it depends on can never come back.
class OpenSignupTest < ActionDispatch::IntegrationTest
  test "an empty deployment offers the first account" do
    assert Invitation.bootstrap?

    get new_user_session_path
    assert_response :success
    assert_match "Create the first account", response.body
    assert_match first_signup_path, response.body
  end

  test "and that account can actually be created" do
    assert_difference "User.count", 1 do
      post first_signup_path, params: { user: {
        name: "John Salva", username: "firstjohn", password: "a-good-password",
        password_confirmation: "a-good-password"
      } }
    end

    assert_redirected_to root_path
    assert_equal "firstjohn", User.sole.username
  end

  test "once somebody exists the offer is gone" do
    create_user(name: "John", username: "alreadyhere")

    refute Invitation.bootstrap?

    get new_user_session_path
    refute_match "Create the first account", response.body

    get first_signup_path
    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_match(/already set up/i, response.body)
  end

  test "and the door cannot be forced by posting straight at it" do
    create_user(name: "John", username: "alreadyhere2")

    assert_no_difference "User.count" do
      post first_signup_path, params: { user: {
        name: "Sneaky", username: "sneaky", password: "a-good-password",
        password_confirmation: "a-good-password"
      } }
    end
    assert_redirected_to new_user_session_path
  end

  # Two people opening an empty deployment at once would both have been shown
  # the form, so the check has to hold at the moment of writing too.
  test "a second person racing for the first account is turned away" do
    get first_signup_path
    assert_response :success

    create_user(name: "Faster", username: "faster")

    assert_no_difference "User.count" do
      post first_signup_path, params: { user: {
        name: "Slower", username: "slower", password: "a-good-password",
        password_confirmation: "a-good-password"
      } }
    end
    assert_redirected_to new_user_session_path
  end

  test "a member's invite link still works after the door has shut" do
    john = create_user(name: "John", username: "hostjohn")
    invitation = Invitation.for(group: nil, creator: john)

    refute Invitation.bootstrap?

    assert_difference "User.count", 1 do
      post signup_path(token: invitation.token), params: { user: {
        name: "Guest", username: "guest", password: "a-good-password",
        password_confirmation: "a-good-password"
      } }
    end
  end

  test "the bootstrap link is worth exactly one account" do
    invitation = Invitation.bootstrap!

    assert_equal 1, invitation.max_uses
    invitation.increment!(:accepted_count)

    refute invitation.reload.usable?
    assert_nil Invitation.live.find_by(id: invitation.id)
  end
end
