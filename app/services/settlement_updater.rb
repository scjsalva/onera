# frozen_string_literal: true

class SettlementUpdater < SettlementWriter
  def self.call(...) = new(...).call

  def initialize(settlement:, actor:, params:)
    super(group: settlement.group, actor:, params:)
    @settlement = settlement
  end

  def call
    return Result.new(settlement: @settlement, errors: [ "A voided settlement can't be edited" ]) if @settlement.voided?

    validate_inputs!
    return Result.new(settlement: @settlement, errors:) if errors.any?

    before = RevisionRecorder.snapshot_for(@settlement)

    ActiveRecord::Base.transaction do
      apply_attributes(@settlement)

      unless @settlement.save
        errors.concat(@settlement.errors.full_messages)
        raise ActiveRecord::Rollback
      end

      after = RevisionRecorder.snapshot_for(@settlement)
      changed = after.select { |key, value| before[key] != value }
                     .transform_values.with_index { |value, _| value }
      RevisionRecorder.record(@settlement, action: "edited", actor:, changed_fields: changed)
      ActivityRecorder.record(
        action: "settlement.edited",
        summary: "#{actor&.name || 'Someone'} edited a settlement between " \
                 "#{@settlement.payer.name} and #{@settlement.recipient.name}",
        group:, actor:, subject: @settlement
      )
    end

    Result.new(settlement: @settlement, errors:)
  end
end
