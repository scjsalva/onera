# frozen_string_literal: true

# Append-only history. Nothing in the app updates or deletes these rows.
class ActivityEvent < ApplicationRecord
  belongs_to :group, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, :summary, :occurred_at, presence: true

  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }
  scope :for_groups, ->(group_ids) { where(group_id: group_ids) }
end
