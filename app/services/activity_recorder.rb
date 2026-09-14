# frozen_string_literal: true

# Writes the human-readable history line for a domain event.
class ActivityRecorder
  def self.record(action:, summary:, group: nil, actor: nil, subject: nil, metadata: {})
    ActivityEvent.create!(
      action:, summary:, group:, actor:, subject:,
      metadata: metadata.compact,
      occurred_at: Time.current
    )
  end
end
