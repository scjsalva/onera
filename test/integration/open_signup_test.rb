# frozen_string_literal: true

require "test_helper"

# Whether strangers can create an account is decided by one thing: does a live
# invitation with no sender exist. That link is what puts a Create an account
# button on the sign-in page, so the button can never disagree with whether
# signing up actually works.
class OpenSignupTest < ActionDispatch::IntegrationTest
  test "no deployment link means no sign-up button" do
    get new_user_session_path

    assert_response :success
    refute_match "Create an account", response.body
  end

  test "a deployment link puts the button on the sign-in page" do
    invitation = Invitation.create!(created_by: nil, group: nil)

    get new_user_session_path
    assert_response :success
    assert_match "Create an account", response.body
    assert_match "/join/#{invitation.token}", response.body
  end

  test "a member's own link is not a deployment link and opens nothing" do
    john = create_user(name: "John", username: "opensignupjohn")
    Invitation.for(group: nil, creator: john)

    get new_user_session_path
    refute_match "Create an account", response.body
    assert_nil Invitation.open_signup
  end

  test "the button leads somewhere that actually works" do
    invitation = Invitation.create!(created_by: nil, group: nil)

    get signup_path(token: invitation.token)
    assert_response :success

    assert_difference "User.count", 1 do
      post signup_path(token: invitation.token), params: { user: {
        name: "Stranger", username: "stranger", password: "a-good-password",
        password_confirmation: "a-good-password"
      } }
    end
    assert_redirected_to root_path
  end

  # A link on a public sign-in page should stop on its own, whether or not
  # anyone remembers to revoke it.
  test "a spent link closes the door and takes the button with it" do
    invitation = Invitation.create!(created_by: nil, group: nil, max_uses: 2)

    2.times { |n| sign_someone_up(invitation, "stranger#{n}") }

    assert_equal 2, invitation.reload.accepted_count
    assert invitation.spent?
    assert_equal 0, invitation.uses_left
    assert_nil Invitation.open_signup

    get new_user_session_path
    refute_match "Create an account", response.body

    assert_no_difference "User.count" do
      post signup_path(token: invitation.token), params: { user: {
        name: "Too Late", username: "toolate", password: "a-good-password",
        password_confirmation: "a-good-password"
      } }
    end
  end

  test "an expired link closes the door too" do
    invitation = Invitation.create!(created_by: nil, group: nil, expires_at: 1.hour.ago)

    assert invitation.expired?
    assert_nil Invitation.open_signup

    get new_user_session_path
    refute_match "Create an account", response.body
  end

  test "a link with no cap keeps working" do
    invitation = Invitation.create!(created_by: nil, group: nil)

    3.times { |n| sign_someone_up(invitation, "unlimited#{n}") }

    refute invitation.reload.spent?
    assert_nil invitation.uses_left
    assert_equal invitation, Invitation.open_signup
  end

  test "revoking the link closes the door and takes the button with it" do
    invitation = Invitation.create!(created_by: nil, group: nil)
    invitation.revoke!

    assert_nil Invitation.open_signup

    get new_user_session_path
    refute_match "Create an account", response.body

    get signup_path(token: invitation.token)
    assert_response :redirect
  end

  private

  def sign_someone_up(invitation, username)
    post signup_path(token: invitation.token), params: { user: {
      name: username.titleize, username:, password: "a-good-password",
      password_confirmation: "a-good-password"
    } }
    delete destroy_user_session_path
  end
end
