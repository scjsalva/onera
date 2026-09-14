# frozen_string_literal: true

class ExchangeRate < ApplicationRecord
  belongs_to :base_currency, class_name: "Currency", foreign_key: :base_currency_code,
                             primary_key: :code, inverse_of: false
  belongs_to :quote_currency, class_name: "Currency", foreign_key: :quote_currency_code,
                              primary_key: :code, inverse_of: false

  validates :rate, numericality: { greater_than: 0 }
  validates :rate_date, presence: true
  validates :base_currency_code, uniqueness: { scope: %i[quote_currency_code rate_date] }
  validate :currencies_differ

  scope :recent_first, -> { order(rate_date: :desc) }

  private

  def currencies_differ
    return if base_currency_code.blank? || base_currency_code != quote_currency_code

    errors.add(:quote_currency_code, "must be different from the base currency")
  end
end
