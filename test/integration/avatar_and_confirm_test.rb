# frozen_string_literal: true

require "test_helper"

class AvatarAndConfirmTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(name: "Picker", username: "pickeruser")
    sign_in_as @user
  end

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
    get "/"
    patch "/email", params: { skip: "Not now" } if response.redirect?
  end

  test "every avatar rendered on a page carries an image" do
    get "/profile"

    # The initials are a fallback layer, not the whole avatar.
    assert_match(/avatar-initials/, response.body)
    assert_match(%r{api\.dicebear\.com}, response.body)
  end

  test "choosing a style saves it" do
    patch "/avatar", params: { avatar_style: "bottts-neutral" }

    assert_equal "bottts-neutral", @user.reload.avatar_style
  end

  test "an invented style is refused rather than stored" do
    patch "/avatar", params: { avatar_style: "not-a-real-style" }

    assert_equal "notionists-neutral", @user.reload.avatar_style
  end

  test "choosing a colour saves it" do
    patch "/avatar", params: { avatar_tone: "12" }

    assert_equal 12, @user.reload.avatar_tone
  end

  test "a colour outside the set is refused rather than stored" do
    patch "/avatar", params: { avatar_tone: "99" }

    assert_nil @user.reload.avatar_tone
  end

  test "shuffling changes the face" do
    before = @user.avatar_url
    patch "/avatar/shuffle"

    refute_equal before, @user.reload.avatar_url
  end

  # data-turbo-confirm did nothing in this app - there is no Turbo - so every
  # destructive action went through unchallenged. These assert the markup the
  # confirm dialog actually listens for.
  test "destructive actions ask before they act" do
    other = create_user(name: "Other", username: "otheruser")
    Friendship.request(from: @user, to: other).accept!

    get "/people"

    assert_match(/data-confirm=/, response.body)
    refute_match(/turbo-confirm/, response.body)
  end

  test "the confirm explains what will happen, not just that something will" do
    other = create_user(name: "Other", username: "otheruser2")
    Friendship.request(from: @user, to: other).accept!

    get "/people"

    assert_match(/data-confirm-detail=/, response.body)
  end
end
