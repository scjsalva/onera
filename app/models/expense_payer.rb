# frozen_string_literal: true

class ExpensePayer < ApplicationRecord
  belongs_to :expense
  belongs_to :user

  validates :amount_minor, numericality: { greater_than: 0, only_integer: true }
  validates :user_id, uniqueness: { scope: :expense_id, message: "is already a payer on this expense" }

  delegate :currency, :base_currency, to: :expense

  def amount = MoneyAmount.new(amount_minor, currency)
  def base_amount = MoneyAmount.new(base_amount_minor, base_currency)
end
