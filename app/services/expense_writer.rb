# frozen_string_literal: true

# Shared machinery for creating and updating an expense.
#
# The client may send a preview of the split, but nothing it sends is trusted:
# the amount, the exchange rate, the per-payer conversion and every share are
# recomputed here before anything is written.
class ExpenseWriter
  Result = Struct.new(:expense, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def initialize(actor:, params:, group: nil, owner: nil)
    @group = group
    @owner = owner
    @actor = actor
    @params = params.to_h.deep_symbolize_keys
    @errors = []
  end

  private

  attr_reader :group, :owner, :actor, :params, :errors

  def personal? = group.nil?

  def currency
    @currency ||= Currency.active.find_by(code: params[:currency_code].presence || base_currency.code)
  end

  # A group's currency governs its expenses. Outside a group there is no group
  # currency, so the owner's own primary currency takes over.
  def base_currency
    @base_currency ||= group ? group.base_currency : owner.preferred_currency
  end

  def amount_minor
    @amount_minor ||= MoneyAmount.from_major(params[:amount].presence || 0, currency).minor
  end

  # The conversion done here is indicative: it exists so the form can show
  # roughly what a foreign expense costs in the group's currency, and it is
  # recalculated on every edit. The rate that the money actually follows is
  # stamped on later by RateLocker at settle-up. The one exception is an
  # expense whose rate is already locked - that rate is reused verbatim so an
  # edit can never quietly re-convert a settled figure.
  def conversion
    @conversion ||= CurrencyConverter.call(
      amount_minor:,
      from: currency,
      to: base_currency,
      rate: locked_rate || params[:exchange_rate].presence,
      on: spent_on
    )
  rescue ArgumentError
    # No rate on file for this pair. The expense is still perfectly valid in
    # its own currency, so it is stored unconverted and shows up at settle-up
    # as a currency that needs a rate before it can be consolidated.
    CurrencyConverter::Result.new(amount_minor:, rate: BigDecimal(1))
  end

  # Overridden by ExpenseUpdater when editing an already-locked expense.
  def locked_rate = nil

  def rate_source
    return "native" if currency.code == base_currency.code

    locked_rate ? "locked" : "indicative"
  end

  def spent_on
    @spent_on ||= begin
      value = params[:spent_on].presence
      value.is_a?(Date) ? value : (Date.parse(value.to_s) rescue Date.current)
    end
  end

  # Nested form fields arrive as an index-keyed hash ({"0" => {...}}) rather
  # than an array, so both shapes are flattened to a plain list of rows.
  def rows(value)
    case value
    when nil then []
    when Array then value
    else value.respond_to?(:values) ? value.values : Array(value)
    end
  end

  def payer_rows
    return @payer_rows ||= [ { user_id: owner.id, amount_minor: } ] if personal?

    @payer_rows ||= rows(params[:payers]).filter_map do |row|
      user_id = row[:user_id].presence&.to_i
      next if user_id.nil?

      minor = MoneyAmount.from_major(row[:amount].presence || 0, currency).minor
      next if minor.zero?

      { user_id:, amount_minor: minor }
    end
  end

  def participant_rows
    return @participant_rows ||= [ { user_id: owner.id, split_value: nil } ] if personal?

    @participant_rows ||= rows(params[:participants]).filter_map do |row|
      user_id = row[:user_id].presence&.to_i
      next if user_id.nil?

      { user_id:, split_value: row[:split_value].presence }
    end
  end

  def split_method
    personal? ? "equal" : (params[:split_method].presence || "equal")
  end

  def split_result
    @split_result ||= SplitCalculator.new(
      total_minor: amount_minor,
      split_method:,
      participants: participant_rows.map { |row| { user_id: row[:user_id], value: row[:split_value] } },
      currency:
    ).call
  end

  # The base-currency total is converted once and then apportioned, so the
  # converted parts always add back up to the converted whole.
  def base_allocation(weights)
    MinorUnitAllocator.allocate(total_minor: conversion.amount_minor, weights:)
  end

  def validate_inputs!
    errors << "Choose a currency" if currency.nil?
    errors << "Enter an amount greater than zero" if currency && !amount_minor.positive?
    unless personal?
      errors << "Choose who paid" if payer_rows.empty?
      errors << "Choose who is sharing this expense" if participant_rows.empty?
    end

    return if errors.any?

    payer_total = payer_rows.sum { |row| row[:amount_minor] }
    if payer_total != amount_minor
      errors << "Payer amounts must add up to #{MoneyAmount.new(amount_minor, currency).format} " \
                "(they currently add up to #{MoneyAmount.new(payer_total, currency).format})"
    end

    errors.concat(split_result.errors) unless split_result.valid?
  end

  def apply_attributes(expense)
    expense.assign_attributes(
      description: params[:description],
      notes: params[:notes].presence,
      category_id: params[:category_id].presence,
      currency_code: currency.code,
      amount_minor: amount_minor,
      base_currency_code: base_currency.code,
      exchange_rate: conversion.rate,
      base_amount_minor: conversion.amount_minor,
      spent_on: spent_on,
      spent_time: params[:spent_time].presence,
      split_method: split_method,
      rate_source: rate_source,
      rate_locked_at: rate_source == "native" ? (expense.rate_locked_at || Time.current) : expense.rate_locked_at
    )
  end

  def rebuild_children(expense)
    payer_base = base_allocation(payer_rows.map { |row| [ row[:user_id], row[:amount_minor] ] })
    expense.expense_payers.destroy_all if expense.persisted?
    payer_rows.each do |row|
      expense.expense_payers.build(
        user_id: row[:user_id],
        amount_minor: row[:amount_minor],
        base_amount_minor: payer_base.fetch(row[:user_id], 0)
      )
    end

    expense.expense_participants.destroy_all if expense.persisted?
    participant_rows.each do |row|
      expense.expense_participants.build(user_id: row[:user_id], split_value: row[:split_value])
    end

    allocations = split_result.allocations
    split_base = base_allocation(allocations.to_a)
    expense.expense_splits.destroy_all if expense.persisted?
    allocations.each do |user_id, minor|
      expense.expense_splits.build(
        user_id: user_id,
        amount_minor: minor,
        base_amount_minor: split_base.fetch(user_id, 0)
      )
    end
  end

  def failure(expense) = Result.new(expense:, errors: errors.uniq)
  def success(expense) = Result.new(expense:, errors: [])
end
