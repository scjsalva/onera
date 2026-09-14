# frozen_string_literal: true

require "test_helper"

class SignupFlowTest < ActionDispatch::IntegrationTest
  setup do
    @host = create_user(name: "Host Person", username: "hostperson")
    @group = create_group(name: "Trip", members: [ @host ], creator: @host)
    @invitation = Invitation.create!(created_by: @host, group: @group)
  end

  def signup(token, attrs)
    get "/join/#{token}"
    csrf = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/join/#{token}", params: { authenticity_token: csrf, user: attrs }
  end

  def valid_attrs(**overrides)
    { name: "New Person", username: "newperson", password: "password123",
      password_confirmation: "password123" }.merge(overrides)
  end

  test "an invite link opens a signup form" do
    get "/join/#{@invitation.token}"

    assert_response :success
    assert_match(/join onera/i, response.body)
  end

  test "an unknown token is turned away" do
    get "/join/not-a-real-token"

    assert_redirected_to "/sign-in"
  end

  test "a revoked link stops working" do
    @invitation.revoke!
    get "/join/#{@invitation.token}"

    assert_redirected_to "/sign-in"
  end

  test "an expired link stops working" do
    @invitation.update!(expires_at: 1.hour.ago)
    get "/join/#{@invitation.token}"

    assert_redirected_to "/sign-in"
  end

  test "signing up creates the account and joins the group" do
    assert_difference -> { User.count }, 1 do
      signup(@invitation.token, valid_attrs)
    end

    user = User.find_by(username: "newperson")

    assert user.member_of?(@group)
    assert_equal 1, @invitation.reload.accepted_count
  end

  test "signing up signs you straight in" do
    signup(@invitation.token, valid_attrs)
    follow_redirect!

    assert_response :success
  end

  test "the person who invited you is told" do
    signup(@invitation.token, valid_attrs)

    assert @host.notifications.where(kind: "group.added").exists?
  end

  test "an email is not required" do
    signup(@invitation.token, valid_attrs)

    assert_nil User.find_by(username: "newperson").email
  end

  test "a duplicate username is refused" do
    assert_no_difference -> { User.count } do
      signup(@invitation.token, valid_attrs(username: "hostperson"))
    end
    assert_response :unprocessable_entity
  end

  test "a username with spaces or symbols is refused" do
    assert_no_difference -> { User.count } do
      signup(@invitation.token, valid_attrs(username: "not a username!"))
    end
  end

  test "a short password is refused" do
    assert_no_difference -> { User.count } do
      signup(@invitation.token, valid_attrs(password: "short", password_confirmation: "short"))
    end
  end

  test "mismatched passwords are refused" do
    assert_no_difference -> { User.count } do
      signup(@invitation.token, valid_attrs(password_confirmation: "different123"))
    end
  end

  test "an invite with no group creates an account without joining anything" do
    open_invite = Invitation.create!(created_by: @host)
    signup(open_invite.token, valid_attrs(username: "loner"))

    assert_empty User.find_by(username: "loner").groups
  end

  test "the share url follows whatever host the app is served from" do
    assert_equal "https://onera.example.com/join/#{@invitation.token}",
                 @invitation.share_url("https://onera.example.com")
    assert_equal "http://localhost:3000/join/#{@invitation.token}",
                 @invitation.share_url("http://localhost:3000/")
  end
end
