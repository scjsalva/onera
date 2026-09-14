# frozen_string_literal: true

# A mutual connection, requested one way and confirmed the other.
#
# Direction only matters until it is accepted: after that the pair is
# symmetric, which is why every lookup here checks both columns.
class Friendship < ApplicationRecord
  belongs_to :requester, class_name: "User"
  belongs_to :addressee, class_name: "User"

  validates :status, inclusion: { in: %w[pending accepted] }
  validate :not_yourself
  validate :not_already_connected, on: :create

  scope :accepted, -> { where(status: "accepted") }
  scope :pending, -> { where(status: "pending") }
  scope :involving, ->(user) { where(requester: user).or(where(addressee: user)) }

  def self.between(one, other)
    involving(one).where(requester: other).or(involving(one).where(addressee: other)).first
  end

  # Asking someone who has already asked you is the same as saying yes - there
  # is no sense in leaving two requests pointing at each other.
  def self.request(from:, to:)
    existing = between(from, to)

    if existing.nil?
      create(requester: from, addressee: to)
    elsif existing.pending? && existing.addressee == from
      existing.accept!
      existing
    else
      existing
    end
  end

  def pending? = status == "pending"
  def accepted? = status == "accepted"

  def accept!
    update!(status: "accepted", responded_at: Time.current)
  end

  # Compares ids rather than records: `user == requester` loads the requester
  # to answer, which on a list of friends is a query per row.
  def other_id(user) = user.id == requester_id ? addressee_id : requester_id
  def other_than(user) = user.id == requester_id ? addressee : requester

  private

  def not_yourself
    return if requester_id.blank? || requester_id != addressee_id

    errors.add(:addressee, "can't be yourself")
  end

  def not_already_connected
    return if requester_id.blank? || addressee_id.blank?
    return if Friendship.between(requester, addressee).nil?

    errors.add(:base, "You're already connected to this person")
  end
end
