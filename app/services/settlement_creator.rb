# frozen_string_literal: true

class SettlementCreator < SettlementWriter
  def self.call(...) = new(...).call

  def call
    validate_inputs!
    return Result.new(settlement: group.settlements.new, errors:) if errors.any?

    settlement = group.settlements.new(created_by: actor)
    apply_attributes(settlement)

    ActiveRecord::Base.transaction do
      unless settlement.save
        errors.concat(settlement.errors.full_messages)
        raise ActiveRecord::Rollback
      end

      RevisionRecorder.record(settlement, action: "created", actor:)
      Notifier.settlement_created(settlement, actor:)
      ActivityRecorder.record(
        action: "settlement.created",
        summary: "#{settlement.payer.name} paid #{settlement.recipient.name} #{settlement.amount.format}",
        group:, actor:, subject: settlement,
        metadata: { amount_minor: settlement.amount_minor, currency: settlement.currency_code }
      )
    end

    errors.any? ? Result.new(settlement:, errors:) : Result.new(settlement:, errors: [])
  end
end
