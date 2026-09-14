# frozen_string_literal: true

# Splits a whole number of minor units across weighted buckets so the parts
# always sum back to the whole.
#
# Used in two places that both must reconcile exactly: dividing an expense
# between participants, and restating already-divided amounts in the group's
# base currency. Converting each row independently would let rounding drift
# away from the converted total, so the total is converted once and then
# apportioned with this.
module MinorUnitAllocator
  module_function

  # weights: array of [key, numeric weight]. Returns { key => minor_units }.
  def allocate(total_minor:, weights:)
    total_minor = total_minor.to_i
    total_weight = weights.sum { |(_, weight)| decimal(weight) }
    return weights.to_h { |(key, _)| [ key, 0 ] } unless total_weight.positive?

    exact = weights.map { |key, weight| [ key, (BigDecimal(total_minor) * decimal(weight)) / total_weight ] }
    allocations = exact.to_h { |key, share| [ key, share.floor ] }

    leftover = total_minor - allocations.values.sum
    ranked = exact.each_with_index
                  .sort_by { |(_key, share), index| [ -(share - share.floor), index ] }
                  .map { |(key, _share), _index| key }

    step = leftover.negative? ? -1 : 1
    leftover.abs.times { |i| allocations[ranked[i % ranked.length]] += step }
    allocations
  end

  def decimal(value)
    value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
  end
end
