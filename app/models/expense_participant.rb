# frozen_string_literal: true

# Who the expense is shared between, plus the raw input for the split method.
# The resolved money lives in ExpenseSplit; this row holds intent.
class ExpenseParticipant < ApplicationRecord
  belongs_to :expense
  belongs_to :user

  validates :user_id, uniqueness: { scope: :expense_id, message: "is already sharing this expense" }
  validates :split_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
