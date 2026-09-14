# frozen_string_literal: true

require "test_helper"

class RecoveryCodeTest < ActiveSupport::TestCase
  setup do
    @user = create_user(name: "Coded", username: "coded", email: "coded@example.com")
  end

  test "a fresh set is ten single-use codes" do
    result = RecoveryCodeIssuer.call(user: @user)

    assert_equal 10, result.codes.size
    assert_equal 10, @user.recovery_codes.count
    assert_equal 10, @user.unused_recovery_codes
  end

  test "codes avoid characters that get misread when copied by hand" do
    RecoveryCodeIssuer.call(user: @user).codes.each do |code|
      assert_no_match(/[O0I1LUV]/, code.delete("-"))
      assert_match(/\A[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}\z/, code)
    end
  end

  test "nothing readable is stored" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first

    assert_empty RecoveryCode.where(code_digest: code)
    assert RecoveryCode.exists?(code_digest: RecoveryCode.digest(code))
  end

  test "typing a code sloppily still works" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first
    sloppy = code.downcase.delete("-")

    result = RecoveryCodeRedeemer.call(email: @user.email, code: sloppy,
                                       password: "new-password-1", password_confirmation: "new-password-1")

    assert result.success?, result.errors.to_sentence
  end

  test "redeeming a code sets the password and spends the code" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first

    RecoveryCodeRedeemer.call(email: @user.email, code:,
                              password: "new-password-1", password_confirmation: "new-password-1")

    assert @user.reload.valid_password?("new-password-1")
    assert_equal 9, @user.unused_recovery_codes
  end

  test "a code works once" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first
    RecoveryCodeRedeemer.call(email: @user.email, code:,
                              password: "new-password-1", password_confirmation: "new-password-1")

    second = RecoveryCodeRedeemer.call(email: @user.email, code:,
                                       password: "another-one-2", password_confirmation: "another-one-2")

    refute second.success?
    refute @user.reload.valid_password?("another-one-2")
  end

  test "a username cannot be used in place of the email" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first

    result = RecoveryCodeRedeemer.call(email: @user.username, code:,
                                       password: "new-password-1", password_confirmation: "new-password-1")

    refute result.success?
  end

  test "someone else's code does not work on your account" do
    other = create_user(name: "Other", username: "othercoded", email: "other@example.com")
    theirs = RecoveryCodeIssuer.call(user: other).codes.first
    RecoveryCodeIssuer.call(user: @user)

    result = RecoveryCodeRedeemer.call(email: @user.email, code: theirs,
                                       password: "new-password-1", password_confirmation: "new-password-1")

    refute result.success?
  end

  test "a wrong email and a wrong code fail identically" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first

    wrong_email = RecoveryCodeRedeemer.call(email: "nobody@example.com", code:,
                                            password: "new-password-1", password_confirmation: "new-password-1")
    wrong_code = RecoveryCodeRedeemer.call(email: @user.email, code: "AAAA-BBBB-CCCC",
                                           password: "new-password-1", password_confirmation: "new-password-1")

    assert_equal wrong_email.errors, wrong_code.errors
  end

  test "a short new password is refused and the code is not spent" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first

    result = RecoveryCodeRedeemer.call(email: @user.email, code:, password: "short", password_confirmation: "short")

    refute result.success?
    assert_equal 10, @user.reload.unused_recovery_codes
  end

  test "mismatched passwords are refused and the code is not spent" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first

    result = RecoveryCodeRedeemer.call(email: @user.email, code:,
                                       password: "one-password", password_confirmation: "two-password")

    refute result.success?
    assert_equal 10, @user.reload.unused_recovery_codes
  end

  test "regenerating replaces the old set entirely" do
    old = RecoveryCodeIssuer.call(user: @user).codes.first
    RecoveryCodeIssuer.call(user: @user)

    result = RecoveryCodeRedeemer.call(email: @user.email, code: old,
                                       password: "new-password-1", password_confirmation: "new-password-1")

    refute result.success?
    assert_equal 10, @user.reload.unused_recovery_codes
  end

  test "a closed account cannot be recovered into" do
    code = RecoveryCodeIssuer.call(user: @user).codes.first
    UserAnonymizer.call(user: @user)

    result = RecoveryCodeRedeemer.call(email: "coded@example.com", code:,
                                       password: "new-password-1", password_confirmation: "new-password-1")

    refute result.success?
  end
end
