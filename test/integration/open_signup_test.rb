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

  test "revoking the link closes the door and takes the button with it" do
    invitation = Invitation.create!(created_by: nil, group: nil)
    invitation.revoke!

    assert_nil Invitation.open_signup

    get new_user_session_path
    refute_match "Create an account", response.body

    get signup_path(token: invitation.token)
    assert_response :redirect
  end
end
