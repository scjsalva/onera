# frozen_string_literal: true

class Notification < ApplicationRecord
  KINDS = %w[
    expense.added expense.edited expense.voided
    settlement.received settlement.recorded
    group.added group.removed
    rates.locked
    friend.requested friend.accepted
    recovery.codes_low
  ].freeze

  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :group, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :kind, :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  # Not called :read - that name already belongs to Object/IO and defining it
  # as a scope silently breaks the class.
  scope :seen, -> { where.not(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def read? = read_at.present?

  # The record this is about may have been removed since. Better to say so
  # than to bounce someone off a "not available" redirect.
  def subject_missing?
    subject_type.present? && subject.nil?
  end

  def mark_read!
    # An endless method with a trailing `unless` would conditionally *define*
    # the method rather than guard the body.
    return if read?

    update!(read_at: Time.current)
  end

  def icon
    case kind
    when /\Aexpense/ then :receipt
    when /\Asettlement/ then :swap
    when /\Agroup/ then :people
    when /\Arates/ then :swap
    when /\Afriend/ then :people
    else :bell
    end
  end
end
