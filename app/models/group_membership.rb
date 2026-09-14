# frozen_string_literal: true

# Deliberately its own model rather than a HABTM join: membership-specific
# attributes (role, nickname, left_at) are expected to land here later.
class GroupMembership < ApplicationRecord
  belongs_to :group
  belongs_to :user

  validates :user_id, uniqueness: { scope: :group_id, message: "is already in this group" }

  before_validation { self.joined_at ||= Time.current }

  scope :ordered, -> { joins(:user).merge(User.ordered) }
end
