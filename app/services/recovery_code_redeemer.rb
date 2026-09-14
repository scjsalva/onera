# frozen_string_literal: true

# Spends one recovery code to set a new password.
#
# Wrong email and wrong code fail identically and take the same path, so the
# form cannot be used to find out which accounts exist.
class RecoveryCodeRedeemer
  Result = Struct.new(:user, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  GENERIC_FAILURE = "That email and recovery code don't match. Check both and try again."

  def self.call(...) = new(...).call

  # Deliberately email, not username. A username is visible to everyone in a
  # group, so allowing a reset against one would let any member start a
  # recovery for anybody else. The email is the thing only the owner has.
  def initialize(email:, code:, password:, password_confirmation:)
    @email = email.to_s.strip.downcase
    @code = code
    @password = password
    @password_confirmation = password_confirmation
  end

  def call
    user = email.present? ? User.active.find_by("lower(email) = ?", email) : nil
    record = user && user.recovery_codes.unused.find_by(code_digest: RecoveryCode.digest(code))

    return Result.new(user: nil, errors: [ GENERIC_FAILURE ]) if record.nil?
    return Result.new(user:, errors: [ "Enter a new password of at least 8 characters" ]) if password.to_s.length < 8
    return Result.new(user:, errors: [ "The two passwords don't match" ]) if password != password_confirmation

    ActiveRecord::Base.transaction do
      user.update!(password:, password_confirmation:)
      record.update!(used_at: Time.current)

      ActivityRecorder.record(
        action: "user.password_recovered",
        summary: "#{user.name} set a new password with #{record.label.downcase}",
        actor: user, subject: user,
        metadata: { position: record.position, remaining: user.recovery_codes.unused.count }
      )
    end

    Result.new(user:, errors: [])
  end

  private

  attr_reader :email, :code, :password, :password_confirmation
end
