require "test_helper"

class RememberMeTest < ActionDispatch::IntegrationTest
  setup do
    # With an email on file, so the sign-in does not land on the prompt asking
    # for one and hide what this test is actually about.
    @user = create_user(name: "John Salva", username: "scjsalva", email: "john@example.com")
  end

  test "ticking stay signed in issues a remember cookie that outlives the session" do
    post user_session_path, params: { user: { login: @user.username, password: "password", remember_me: "1" } }
    assert_redirected_to root_path

    assert @user.reload.remember_created_at.present?, "no remember token was stored"

    assert cookies["remember_user_token"].present?, "no remember cookie was set"

    # Throw the session away, the way closing the browser does, and keep only
    # the remember cookie.
    token = cookies["remember_user_token"]
    reset!
    cookies["remember_user_token"] = token

    get root_path
    assert_response :success, "the remember cookie did not sign me back in"
  end

  test "leaving it unticked does not remember" do
    post user_session_path, params: { user: { login: @user.username, password: "password", remember_me: "0" } }
    assert_nil @user.reload.remember_created_at
    assert cookies["remember_user_token"].blank?
  end

  test "the remember window is six months" do
    assert_equal 6.months, Devise.remember_for
  end

  test "the cookie itself is set to last six months, not the browser session" do
    post user_session_path, params: { user: { login: @user.username, password: "password", remember_me: "1" } }

    header = response.headers["Set-Cookie"]
    lines = header.is_a?(Array) ? header : header.to_s.split("\n")
    remember = lines.find { |line| line.start_with?("remember_user_token") }
    assert remember, "no remember cookie in the response (#{lines.map { |l| l[/\A[^=]+/] }.inspect})"

    expires = Time.parse(remember[/expires=([^;]+)/i, 1])
    assert_operator expires, :>, 5.months.from_now
  end
end
