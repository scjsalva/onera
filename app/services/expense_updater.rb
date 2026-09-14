# frozen_string_literal: true

# Editing recalculates the split, the conversion and every derived amount from
# scratch. The previous state is kept as a revision rather than overwritten.
class ExpenseUpdater < ExpenseWriter
  def self.call(...) = new(...).call

  def initialize(expense:, actor:, params:)
    super(group: expense.group, owner: expense.owner, actor:, params:)
    @expense = expense
  end

  def call
    return Result.new(expense: @expense, errors: [ "A voided expense can't be edited" ]) if @expense.voided?

    validate_inputs!
    return failure(@expense) if errors.any?

    before = RevisionRecorder.snapshot_for(@expense)

    ActiveRecord::Base.transaction do
      apply_attributes(@expense)
      rebuild_children(@expense)

      unless @expense.save
        errors.concat(@expense.errors.full_messages)
        raise ActiveRecord::Rollback
      end

      after = RevisionRecorder.snapshot_for(@expense.reload)
      RevisionRecorder.record(@expense, action: "edited", actor:, changed_fields: diff(before, after))
      ActivityRecorder.record(
        action: "expense.edited",
        summary: "#{actor&.name || 'Someone'} edited #{@expense.description}",
        group:, actor:, subject: @expense
      )
    end

    errors.any? ? failure(@expense) : success(@expense)
  end

  private

  def locked_rate = @expense.rate_locked? && !@expense.native_currency? ? @expense.exchange_rate : nil

  def diff(before, after)
    after.each_with_object({}) do |(key, value), memo|
      memo[key] = { from: before[key], to: value } if before[key] != value
    end
  end
end
