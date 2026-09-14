# frozen_string_literal: true

class Currency < ApplicationRecord
  self.primary_key = "code"

  has_many :groups, foreign_key: :base_currency_code, inverse_of: :base_currency, dependent: :restrict_with_error
  has_many :expenses, foreign_key: :currency_code, inverse_of: :currency, dependent: :restrict_with_error
  has_many :settlements, foreign_key: :currency_code, inverse_of: :currency, dependent: :restrict_with_error

  validates :code, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :name, :symbol, presence: true
  validates :exponent, numericality: { in: 0..4 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :code) }

  def subunit_factor = 10**exponent

  def to_param = code
end
