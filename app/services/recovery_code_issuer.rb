# frozen_string_literal: true

# Issues a fresh set of recovery codes, replacing whatever the person had.
#
# The plaintext is returned once, to be shown once. It is never stored, so
# regenerating is the only way back if the list is lost - which is the same
# bargain as any other recovery code system, and the reason the UI pushes
# people to save them at the moment they are created.
class RecoveryCodeIssuer
  Result = Struct.new(:codes, :user, keyword_init: true)

  def self.call(...) = new(...).call

  def initialize(user:, actor: nil)
    @user = user
    @actor = actor
  end

  def call
    plaintext = []

    ActiveRecord::Base.transaction do
      user.recovery_codes.delete_all

      RecoveryCode::PER_USER.times do |index|
        code = unique_code
        plaintext << code
        user.recovery_codes.create!(
          position: index + 1,
          code_digest: RecoveryCode.digest(code)
        )
      end

      user.update!(recovery_codes_generated_at: Time.current)

      ActivityRecorder.record(
        action: "user.recovery_codes_issued",
        summary: "#{user.name} generated new recovery codes",
        actor: actor || user, subject: user
      )
    end

    Result.new(codes: plaintext, user:)
  end

  private

  attr_reader :user, :actor

  # The digest column is unique across everyone, so a collision - however
  # unlikely - would otherwise fail the whole batch.
  def unique_code
    loop do
      candidate = RecoveryCode.generate_plaintext
      return candidate unless RecoveryCode.exists?(code_digest: RecoveryCode.digest(candidate))
    end
  end
end
