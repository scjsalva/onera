# frozen_string_literal: true

# Turns a split method plus per-person inputs into exact minor-unit shares.
#
# Two rules govern everything here:
#   1. The allocated shares always sum to exactly the expense total. No cent is
#      ever created or lost by rounding.
#   2. The same inputs always produce the same outputs. Remainders are handed
#      out by the largest-remainder method, ties broken by participant order,
#      so a recalculation on edit never silently reshuffles who absorbed the
#      odd cent.
class SplitCalculator
  Participant = Struct.new(:user_id, :value, keyword_init: true)

  Result = Struct.new(:allocations, :errors, keyword_init: true) do
    def valid? = errors.empty?
    def amount_for(user_id) = allocations.fetch(user_id, 0)
  end

  def initialize(total_minor:, split_method:, participants:, currency:)
    @total_minor = total_minor.to_i
    @split_method = split_method.to_s
    @participants = participants.map { |p| p.is_a?(Participant) ? p : Participant.new(**p) }
    @currency = currency
  end

  def call
    return failure("Add at least one person to split this expense with") if participants.empty?
    return failure("The expense total must be greater than zero") unless total_minor.positive?

    case split_method
    when "equal"      then equal_split
    when "percentage" then percentage_split
    when "fixed"      then fixed_split
    when "shares"     then shares_split
    else failure("#{split_method.inspect} is not a supported split method")
    end
  end

  private

  attr_reader :total_minor, :split_method, :participants, :currency

  def equal_split
    success(allocate(participants.map { |p| [ p.user_id, BigDecimal(1) ] }))
  end

  def percentage_split
    percentages = participants.map { |p| [ p.user_id, decimal(p.value) ] }
    total = percentages.sum { |(_, value)| value }

    return failure("Percentages must add up to 100% (they currently add up to #{format_number(total)}%)") unless total == 100
    return failure("Every percentage must be zero or more") if percentages.any? { |(_, value)| value.negative? }

    success(allocate(percentages))
  end

  def fixed_split
    amounts = participants.map { |p| [ p.user_id, MoneyAmount.from_major(decimal(p.value), currency).minor ] }
    total = amounts.sum { |(_, minor)| minor }

    if total != total_minor
      return failure("Exact amounts must add up to #{MoneyAmount.new(total_minor, currency).format} " \
                     "(they currently add up to #{MoneyAmount.new(total, currency).format})")
    end
    return failure("Every amount must be zero or more") if amounts.any? { |(_, minor)| minor.negative? }

    success(amounts.to_h)
  end

  def shares_split
    shares = participants.map { |p| [ p.user_id, decimal(p.value) ] }

    return failure("Every share must be zero or more") if shares.any? { |(_, value)| value.negative? }
    return failure("Shares must add up to more than zero") unless shares.sum { |(_, value)| value }.positive?

    success(allocate(shares))
  end

  def allocate(weighted)
    MinorUnitAllocator.allocate(total_minor:, weights: weighted)
  end

  def decimal(value) = value.is_a?(BigDecimal) ? value : BigDecimal(value.presence.to_s.presence || "0")

  def format_number(value) = value.frac.zero? ? value.to_i.to_s : value.to_s("F")

  def success(allocations) = Result.new(allocations:, errors: [])
  def failure(message) = Result.new(allocations: {}, errors: [ message ])
end
