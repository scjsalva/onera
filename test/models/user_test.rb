# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "a username is required and must look like one" do
    assert_invalid username: nil
    assert_invalid username: "ab"
    assert_invalid username: "has space"
    assert_invalid username: "no!symbols"
    assert_invalid username: "a" * 31
    assert_valid username: "john.carlo-salva_1"
  end

  test "usernames are stored lowercase and are unique regardless of case" do
    create_user(name: "First", username: "TakenName")

    assert_equal "takenname", User.find_by(name: "First").username
    assert_invalid username: "TAKENNAME"
  end

  test "email is optional" do
    assert_valid email: nil
    assert_valid email: ""
  end

  test "an email, if given, must be usable and unique" do
    assert_invalid email: "not-an-email"

    create_user(name: "Holder", username: "holder", email: "held@example.com")
    assert_invalid email: "HELD@example.com"
  end

  test "a password shorter than eight characters is refused" do
    user = User.new(name: "Short", username: "shortpw", password: "abc1234", password_confirmation: "abc1234")

    refute user.valid?
  end

  test "a mismatched confirmation is refused" do
    user = User.new(name: "Mismatch", username: "mismatch",
                    password: "goodpassword", password_confirmation: "otherpassword")

    refute user.valid?
    assert_includes user.errors.full_messages.join, "onfirmation"
  end

  test "age is derived and never stored" do
    user = create_user(name: "Aged", username: "aged", date_of_birth: Date.new(1998, 1, 15))

    assert_equal 28, user.age(on: Date.new(2026, 1, 15))
    assert_equal 27, user.age(on: Date.new(2026, 1, 14))
    refute User.column_names.include?("age")
  end

  test "a birthday in the future is refused" do
    user = User.new(name: "Future", username: "future", password: "password",
                    password_confirmation: "password", date_of_birth: Date.current + 1)

    refute user.valid?
  end

  test "initials come from the name" do
    assert_equal "JS", create_user(name: "John Salva", username: "jsalva1").initials
    assert_equal "M", create_user(name: "Madonna", username: "mad1").initials
    assert_equal "JC", create_user(name: "john carlo salva", username: "jcs1").initials
  end

  test "a closed account gets its own number so two are never alike" do
    first = create_user(name: "One", username: "closeone")
    second = create_user(name: "Two", username: "closetwo")

    UserAnonymizer.call(user: first)
    UserAnonymizer.call(user: second)

    assert_equal "Removed person 1", first.reload.name
    assert_equal "Removed person 2", second.reload.name
    assert_equal "R1", first.initials
    assert_equal "R2", second.initials
    refute_equal first.initials, second.initials
  end

  test "closing an account erases the identifying details" do
    user = create_user(name: "Gone", username: "gone", email: "gone@example.com",
                       date_of_birth: Date.new(1990, 5, 1))
    UserAnonymizer.call(user:)
    user.reload

    assert user.archived?
    refute_equal "gone@example.com", user.email
    assert_nil user.date_of_birth
    assert_empty user.recovery_codes
  end

  test "a closed account keeps its row so expenses still resolve" do
    user = create_user(name: "Keeper", username: "keeper")
    id = user.id
    UserAnonymizer.call(user:)

    assert User.exists?(id)
  end

  test "closed accounts drop out of the pickers but stay findable by id" do
    user = create_user(name: "Hidden", username: "hidden")
    UserAnonymizer.call(user:)

    refute_includes User.active, user
    assert_includes User.archived, user.reload
  end

  test "a closed account has no avatar to draw" do
    user = create_user(name: "Faceless", username: "faceless")

    assert user.avatar_url.present?
    UserAnonymizer.call(user:)
    assert_nil user.reload.avatar_url
  end

  test "the avatar is stable for the same person" do
    user = create_user(name: "Stable", username: "stable")

    assert_equal user.avatar_url, user.reload.avatar_url
    assert_includes user.avatar_url, "stable"
  end

  test "the colour is derived until someone picks one" do
    user = create_user(name: "Toned", username: "toneduser")

    assert_includes User::AVATAR_TONES, user.tone_number
    assert_equal "bg-avatar-#{user.tone_number}", user.tone_class

    user.update!(avatar_tone: 12)
    assert_equal "bg-avatar-12", user.reload.tone_class
  end

  test "pale colours pair with dark initials and deep ones with white" do
    user = create_user(name: "Pale", username: "paleuser")

    user.update!(avatar_tone: 3)
    assert_equal "text-white", user.tone_text_class

    user.update!(avatar_tone: 12)
    assert_equal "text-ink-900", user.tone_text_class
  end

  test "a colour outside the set is refused" do
    user = create_user(name: "Bad", username: "baduser")

    user.avatar_tone = 99
    refute user.valid?
  end

  test "the avatar style must be one of the offered set" do
    user = create_user(name: "Styled", username: "styled")

    user.avatar_style = "bottts-neutral"
    assert user.valid?

    user.avatar_style = "something-invented"
    refute user.valid?
  end

  test "shuffling changes the face without changing the name" do
    user = create_user(name: "Shuffler", username: "shuffler")
    before = user.avatar_url

    user.reroll_avatar!

    refute_equal before, user.reload.avatar_url
    assert_equal "Shuffler", user.name
    assert_equal "shuffler", user.username
  end

  test "the avatar follows the chosen style" do
    user = create_user(name: "Robot", username: "robotuser", avatar_style: "bottts-neutral")

    assert_includes user.avatar_url, "bottts-neutral"
  end

  test "a style can be previewed without saving it" do
    user = create_user(name: "Preview", username: "previewuser")

    assert_includes user.avatar_url(style: "fun-emoji"), "fun-emoji"
    assert_equal "notionists-neutral", user.reload.avatar_style
  end

  private

  def assert_valid(**attrs)
    assert build_user(**attrs).valid?, "expected #{attrs.inspect} to be valid"
  end

  def assert_invalid(**attrs)
    refute build_user(**attrs).valid?, "expected #{attrs.inspect} to be refused"
  end

  def build_user(**attrs)
    User.new({ name: "Candidate", username: "candidate", password: "password",
               password_confirmation: "password" }.merge(attrs))
  end
end
