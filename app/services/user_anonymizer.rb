# frozen_string_literal: true

# "Delete" for a person who appears in financial records.
#
# The row survives, because expenses, payers, splits and settlements point at
# it - destroying it would either orphan that history or cascade a delete
# through records the app promises never to destroy. What is removed is the
# identity: name, email and date of birth are cleared for good.
#
# Each anonymized person keeps a number, so a group with two of them shows
# "Removed person 1" and "Removed person 2" rather than two identical rows.
# Their avatar colour is derived from the id and stays distinct too.
class UserAnonymizer
  Result = Struct.new(:user, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def self.call(...) = new(...).call

  def initialize(user:, actor: nil)
    @user = user
    @actor = actor
  end

  def call
    return Result.new(user:, errors: [ "This person has already been removed" ]) if user.archived?

    former_name = user.name

    ActiveRecord::Base.transaction do
      ordinal = (User.archived.maximum(:archived_ordinal) || 0) + 1

      user.update!(
        name: "Removed person #{ordinal}",
        email: nil,
        date_of_birth: nil,
        archived_at: Time.current,
        archived_ordinal: ordinal
      )

      # The event deliberately does not record the old name - anonymising and
      # then writing the name into the history would defeat the point.
      ActivityRecorder.record(
        action: "user.archived",
        summary: "#{user.name} was removed from Onera",
        actor: actor == user ? nil : actor,
        subject: user,
        metadata: { ordinal: }
      )
    end

    Result.new(user:, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(user:, errors: [ e.record.errors.full_messages.to_sentence.presence || "Could not remove #{former_name}" ])
  end

  private

  attr_reader :user, :actor
end
