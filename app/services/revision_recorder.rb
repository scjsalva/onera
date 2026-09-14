# frozen_string_literal: true

# Snapshots an expense or settlement after every write so the record's history
# can be replayed. Snapshots are stored, never mutated.
class RevisionRecorder
  def self.record(record, action:, actor: nil, changed_fields: {})
    number = record.revisions.maximum(:revision_number).to_i + 1

    record.revisions.create!(
      actor:,
      action:,
      revision_number: number,
      snapshot: snapshot_for(record),
      changed_fields: changed_fields,
      occurred_at: Time.current
    )
  end

  def self.snapshot_for(record)
    case record
    when Expense then expense_snapshot(record)
    when Settlement then settlement_snapshot(record)
    else record.attributes
    end
  end

  def self.expense_snapshot(expense)
    {
      description: expense.description,
      notes: expense.notes,
      category: expense.category&.name,
      currency_code: expense.currency_code,
      amount_minor: expense.amount_minor,
      base_currency_code: expense.base_currency_code,
      base_amount_minor: expense.base_amount_minor,
      exchange_rate: expense.exchange_rate.to_s("F"),
      spent_on: expense.spent_on.to_s,
      spent_time: expense.spent_time&.strftime("%H:%M"),
      split_method: expense.split_method,
      voided_at: expense.voided_at&.iso8601,
      payers: expense.expense_payers.map { |p| { user_id: p.user_id, amount_minor: p.amount_minor } },
      splits: expense.expense_splits.map { |s| { user_id: s.user_id, amount_minor: s.amount_minor } }
    }
  end

  def self.settlement_snapshot(settlement)
    {
      payer_id: settlement.payer_id,
      recipient_id: settlement.recipient_id,
      currency_code: settlement.currency_code,
      amount_minor: settlement.amount_minor,
      base_currency_code: settlement.base_currency_code,
      base_amount_minor: settlement.base_amount_minor,
      exchange_rate: settlement.exchange_rate.to_s("F"),
      settled_on: settlement.settled_on.to_s,
      payment_method: settlement.payment_method,
      note: settlement.note,
      voided_at: settlement.voided_at&.iso8601
    }
  end

  private_class_method :expense_snapshot, :settlement_snapshot
end
