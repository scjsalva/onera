# frozen_string_literal: true

class Group < ApplicationRecord
  belongs_to :base_currency, class_name: "Currency", foreign_key: :base_currency_code,
                             primary_key: :code, inverse_of: :groups
  belongs_to :created_by, class_name: "User", optional: true, inverse_of: :created_groups

  has_many :group_memberships, dependent: :destroy
  has_many :users, through: :group_memberships
  has_many :expenses, dependent: :restrict_with_error
  has_many :settlements, dependent: :restrict_with_error
  has_many :activity_events, dependent: :destroy
  # Both reference the group, so deleting an empty one failed on a foreign key
  # rather than on anything the person could see or fix.
  has_many :invitations, dependent: :destroy
  has_many :notifications, dependent: :nullify

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 2_000 }

  scope :ordered, -> { order(:name, :id) }
  scope :active, -> { where(archived_at: nil) }

  def archived? = archived_at.present?

  def member_ids = group_memberships.pluck(:user_id)
end
