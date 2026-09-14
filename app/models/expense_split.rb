# frozen_string_literal: true

# The authoritative per-person share. Always written by SplitCalculator, never
# by user input, and always sums exactly to the expense total.
class ExpenseSplit < ApplicationRecord
  belongs_to :expense
  belongs_to :user

  validates :amount_minor, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :user_id, uniqueness: { scope: :expense_id }

  delegate :currency, :base_currency, to: :expense

  def amount = MoneyAmount.new(amount_minor, currency)
  def base_amount = MoneyAmount.new(base_amount_minor, base_currency)
end
