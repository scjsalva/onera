# frozen_string_literal: true

# A point-in-time snapshot of an expense or settlement, written on every
# create, edit and void so a historical record can always be explained.
class Revision < ApplicationRecord
  belongs_to :revisable, polymorphic: true
  belongs_to :actor, class_name: "User", optional: true

  validates :action, :revision_number, :occurred_at, presence: true

  scope :chronological, -> { order(:revision_number) }
  scope :recent_first, -> { order(revision_number: :desc) }
end
