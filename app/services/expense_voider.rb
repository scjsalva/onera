# frozen_string_literal: true

# Financial records are never deleted. Voiding keeps the row and its history
# but removes it from every active balance and total.
class ExpenseVoider
  Result = Struct.new(:expense, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def self.call(...) = new(...).call

  def initialize(expense:, actor:, reason: nil)
    @expense = expense
    @actor = actor
    @reason = reason.presence
  end

  def call
    return Result.new(expense:, errors: [ "This expense is already voided" ]) if expense.voided?

    ActiveRecord::Base.transaction do
      expense.update!(voided_at: Time.current, voided_by: actor, void_reason: reason)
      RevisionRecorder.record(expense, action: "voided", actor:, changed_fields: { void_reason: reason })
      ActivityRecorder.record(
        action: "expense.voided",
        summary: "#{actor&.name || 'Someone'} voided #{expense.description}",
        group: expense.group, actor:, subject: expense,
        metadata: { reason: }
      )
    end

    Result.new(expense:, errors: [])
  end

  def restore
    return Result.new(expense:, errors: [ "This expense is not voided" ]) unless expense.voided?

    ActiveRecord::Base.transaction do
      expense.update!(voided_at: nil, voided_by: nil, void_reason: nil)
      RevisionRecorder.record(expense, action: "restored", actor:)
      ActivityRecorder.record(
        action: "expense.restored",
        summary: "#{actor&.name || 'Someone'} restored #{expense.description}",
        group: expense.group, actor:, subject: expense
      )
    end

    Result.new(expense:, errors: [])
  end

  private

  attr_reader :expense, :actor, :reason
end
