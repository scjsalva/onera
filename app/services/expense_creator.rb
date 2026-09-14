# frozen_string_literal: true

class ExpenseCreator < ExpenseWriter
  def self.call(...) = new(...).call

  def call
    validate_inputs!
    return failure(group.expenses.new) if errors.any?

    expense = group.expenses.new(created_by: actor)
    apply_attributes(expense)
    rebuild_children(expense)

    ActiveRecord::Base.transaction do
      unless expense.save
        errors.concat(expense.errors.full_messages)
        raise ActiveRecord::Rollback
      end

      RevisionRecorder.record(expense, action: "created", actor:)
      ActivityRecorder.record(
        action: "expense.created",
        summary: "#{actor&.name || 'Someone'} added #{expense.description} (#{expense.amount.format})",
        group:, actor:, subject: expense,
        metadata: { amount_minor: expense.amount_minor, currency: expense.currency_code }
      )
    end

    errors.any? ? failure(expense) : success(expense)
  end
end
