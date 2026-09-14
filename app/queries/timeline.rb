# frozen_string_literal: true

# Expenses and settlements in one chronological list.
#
# Kept together because the order is the story: an expense, another expense,
# then somebody paying somebody back. Reading them on separate tabs makes you
# reconstruct that order in your head.
class Timeline
  Entry = Struct.new(:record, :date, keyword_init: true) do
    def expense? = record.is_a?(Expense)
    def settlement? = record.is_a?(Settlement)
  end

  def initialize(expenses:, settlements:, include_settlements: true)
    @expenses = expenses
    @settlements = settlements
    @include_settlements = include_settlements
  end

  def entries
    @entries ||= begin
      rows = @expenses.map { |e| Entry.new(record: e, date: e.spent_on) }
      rows += settlements.map { |s| Entry.new(record: s, date: s.settled_on) } if @include_settlements
      rows.sort_by { |entry| [ -entry.date.to_time.to_i, -entry.record.created_at.to_i ] }
    end
  end

  def any? = entries.any?
  def settlements = @include_settlements ? @settlements.to_a : []

  # Filters that describe an expense - a category, a currency, who paid - have
  # no meaning for a settlement, so mixing them in would be misleading.
  def self.settlements_relevant?(filter)
    filter.category_id.blank? && filter.currency_code.blank? &&
      filter.min_amount.blank? && filter.max_amount.blank? &&
      filter.status == "active" && filter.query.blank?
  end
end
