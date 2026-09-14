# frozen_string_literal: true

class Category < ApplicationRecord
  has_many :expenses, dependent: :nullify

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 60 }
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9\-]+\z/ }

  before_validation :derive_slug, on: :create

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  private

  def derive_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end
end
