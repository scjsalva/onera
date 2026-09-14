# frozen_string_literal: true

# Settlements are voided, never destroyed, so the payment history stays intact.
class SettlementVoider
  Result = Struct.new(:settlement, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def self.call(...) = new(...).call

  def initialize(settlement:, actor:)
    @settlement = settlement
    @actor = actor
  end

  def call
    return Result.new(settlement:, errors: [ "This settlement is already voided" ]) if settlement.voided?

    ActiveRecord::Base.transaction do
      settlement.update!(voided_at: Time.current, voided_by: actor)
      RevisionRecorder.record(settlement, action: "voided", actor:)
      ActivityRecorder.record(
        action: "settlement.voided",
        summary: "#{actor&.name || 'Someone'} voided a settlement between " \
                 "#{settlement.payer.name} and #{settlement.recipient.name}",
        group: settlement.group, actor:, subject: settlement
      )
    end

    Result.new(settlement:, errors: [])
  end

  private

  attr_reader :settlement, :actor
end
