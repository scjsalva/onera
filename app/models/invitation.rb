# frozen_string_literal: true

# A shareable link that lets someone create their own account.
#
# Accounts are no longer made on another person's behalf, so this is how
# somebody new gets in: a member sends them a link. An invitation can carry a
# group, in which case accepting it also joins that group.
class Invitation < ApplicationRecord
  # Optional: a fresh deployment has nobody to have sent the link, and the
  # first person through the door needs one anyway.
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :group, optional: true

  before_validation :assign_token, on: :create

  validates :token, presence: true, uniqueness: true

  scope :live, lambda {
    where(revoked_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
      .where("max_uses IS NULL OR accepted_count < max_uses")
  }

  def self.for(group:, creator:)
    live.find_by(group:, created_by: creator) || create!(group:, created_by: creator)
  end

  # Who to credit on the join page. Nil for a link that came with the
  # deployment rather than from a person.
  def referrer_name = created_by&.name

  # The deployment's own link, if it has one: no sender, no group, still live.
  #
  # Its existence is what puts a Create an account button on the sign-in page,
  # so this is the whole of the open-signup switch. `onera:invite` opens the
  # door and `onera:revoke_invites` closes it - no setting to remember, and
  # nothing that can disagree with what the button says.
  def self.open_signup = live.find_by(created_by: nil, group: nil)

  def revoked? = revoked_at.present?
  def expired? = expires_at.present? && expires_at <= Time.current
  def spent? = max_uses.present? && accepted_count >= max_uses
  def usable? = !revoked? && !expired? && !spent?
  def uses_left = max_uses && [ max_uses - accepted_count, 0 ].max

  def revoke! = update!(revoked_at: Time.current)

  # Built from the request rather than a configured host, so the link is
  # correct on localhost, on a preview deploy and in production without
  # anything to remember to change.
  def share_url(base_url) = "#{base_url.chomp('/')}/join/#{token}"

  private

  def assign_token
    self.token ||= loop do
      candidate = SecureRandom.urlsafe_base64(12).tr("-_", "aB")
      break candidate unless Invitation.exists?(token: candidate)
    end
  end
end
