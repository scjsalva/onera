# frozen_string_literal: true

require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(name: "Signed In", username: "signedin")
  end

  def sign_in_as(login, password: "password")
    get "/sign-in"
    token = css_token
    post "/sign-in", params: { authenticity_token: token, user: { login:, password: } }
  end

  def css_token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]

  # The first page load after signing in is intercepted once to ask for an
  # email. A test about something else should step past it rather than trip
  # over it - and the interception is what marks it as asked.
  def past_email_prompt
    get "/"
    patch "/email", params: { skip: "Not now" } if response.redirect?
  end

  test "the dashboard is closed to strangers" do
    get "/"

    assert_redirected_to "/sign-in"
  end

  test "signing in with a username works" do
    sign_in_as "signedin"

    assert_response :redirect
    past_email_prompt
    get "/"
    assert_response :success
  end

  test "signing in with an email works once one is set" do
    @user.update!(email: "signed.in@example.com")
    sign_in_as "signed.in@example.com"

    assert_response :redirect
  end

  test "the login field is case-insensitive" do
    sign_in_as "SignedIn"

    assert_response :redirect
  end

  test "a wrong password is refused" do
    sign_in_as "signedin", password: "nope"

    assert_response :unprocessable_entity
    assert_match(/invalid/i, response.body)
  end

  test "an unknown login is refused the same way as a wrong password" do
    sign_in_as "ghost"

    assert_response :unprocessable_entity
    assert_match(/invalid/i, response.body)
  end

  test "closing an account actually closes it" do
    result = UserAnonymizer.call(user: @user)

    assert result.success?, result.errors.to_sentence
    assert @user.reload.archived?
    refute @user.valid_password?("password"), "the old password must stop working"
  end

  test "a closed account cannot sign in" do
    UserAnonymizer.call(user: @user)
    sign_in_as "signedin"

    assert_response :unprocessable_entity
  end

  test "the first sign-in asks for an email, once" do
    sign_in_as "signedin"
    get "/"

    assert_redirected_to "/email/edit"

    patch "/email", params: { skip: "Not now" }
    get "/"

    assert_response :success
  end

  test "the prompt does not follow you around after it has been shown" do
    sign_in_as "signedin"
    get "/"

    assert_redirected_to "/email/edit"

    # Navigating away instead of answering must not bounce you again, or
    # every page becomes the prompt.
    get "/groups"

    assert_response :success
  end

  test "the prompt comes back on the next sign-in" do
    sign_in_as "signedin"
    get "/"
    assert_redirected_to "/email/edit"

    delete "/sign-out"
    sign_in_as "signedin"
    get "/"

    assert_redirected_to "/email/edit"
  end

  test "someone who already has an email is never asked" do
    @user.update!(email: "has@example.com")
    sign_in_as "signedin"
    get "/"

    assert_response :success
  end

  test "an email given at the prompt becomes a second way in" do
    sign_in_as "signedin"
    patch "/email", params: { user: { email: "later@example.com" } }

    assert_equal "later@example.com", @user.reload.email
    assert_equal @user, User.find_for_database_authentication(login: "later@example.com")
  end

  test "an email already taken is refused" do
    create_user(name: "Other", username: "other", email: "taken@example.com")
    sign_in_as "signedin"
    patch "/email", params: { user: { email: "taken@example.com" } }

    assert_response :unprocessable_entity
    assert_nil @user.reload.email
  end
end
