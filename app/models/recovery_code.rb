# frozen_string_literal: true

# A single-use code that lets someone set a new password without email.
#
# Only the digest is stored, so a code can be verified but never read back.
# The lookup is by digest, which means verification is one indexed query
# rather than a comparison against every code the person holds.
class RecoveryCode < ApplicationRecord
  # Deliberately excludes characters that get misread when copied by hand:
  # no O/0, no I/1, no L, no U/V confusion.
  ALPHABET = "ABCDEFGHJKMNPQRSTWXYZ23456789"
  GROUPS = 3
  GROUP_SIZE = 4
  PER_USER = 10

  belongs_to :user

  validates :code_digest, presence: true, uniqueness: true
  validates :position, presence: true, uniqueness: { scope: :user_id }

  scope :unused, -> { where(used_at: nil) }
  scope :used, -> { where.not(used_at: nil) }
  scope :ordered, -> { order(:position) }

  def self.generate_plaintext
    GROUPS.times.map { GROUP_SIZE.times.map { ALPHABET.chars.sample(random: SecureRandom) }.join }.join("-")
  end

  # Normalised so case and stray spaces or dashes don't matter to the person
  # typing it in.
  def self.normalize(code)
    cleaned = code.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    cleaned.chars.each_slice(GROUP_SIZE).map(&:join).join("-")
  end

  def self.digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", secret, normalize(code))
  end

  def self.secret
    Rails.application.key_generator.generate_key("recovery-codes", 32)
  end

  def used? = used_at.present?

  def label = "Code #{position}"
end
