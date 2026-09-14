# frozen_string_literal: true

require "test_helper"

# The mark animates on the pages people wait on, and only on hover in the
# chrome. A logo that never stops moving on every page is not a flourish.
class MarkTest < ActionDispatch::IntegrationTest
  test "it animates on the sign-in page" do
    get new_user_session_path

    assert_response :success
    assert_match "onera-mark-left", response.body
    assert_match "onera-mark-right", response.body
    refute_match "onera-mark-hover", response.body
  end

  test "it animates on the join page too" do
    invitation = Invitation.create!(created_by: nil, group: nil)

    get signup_path(token: invitation.token)
    assert_response :success
    assert_match "onera-mark-left", response.body
  end

  test "in the chrome it waits to be hovered" do
    user = create_user(name: "John", username: "markjohn", email: "mark@example.com")
    sign_in_as(user)

    get root_path
    assert_response :success
    # The wrapper is what holds the animation back; without it the logo would
    # move on every page, all the time.
    assert_match "onera-mark-hover", response.body
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
