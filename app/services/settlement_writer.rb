# frozen_string_literal: true

class SettlementWriter
  Result = Struct.new(:settlement, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def initialize(group:, actor:, params:)
    @group = group
    @actor = actor
    @params = params.to_h.deep_symbolize_keys
    @errors = []
  end

  private

  attr_reader :group, :actor, :params, :errors

  def currency
    @currency ||= Currency.active.find_by(code: params[:currency_code].presence || group.base_currency_code)
  end

  def base_currency = group.base_currency

  def amount_minor
    @amount_minor ||= MoneyAmount.from_major(params[:amount].presence || 0, currency).minor
  end

  def settled_on
    @settled_on ||= begin
      value = params[:settled_on].presence
      value.is_a?(Date) ? value : (Date.parse(value.to_s) rescue Date.current)
    end
  end

  def conversion
    @conversion ||= CurrencyConverter.call(
      amount_minor:, from: currency, to: base_currency,
      rate: params[:exchange_rate].presence, on: settled_on
    )
  rescue ArgumentError
    CurrencyConverter::Result.new(amount_minor:, rate: BigDecimal(1))
  end

  def validate_inputs!
    errors << "Choose a currency" if currency.nil?
    errors << "Enter an amount greater than zero" if currency && !amount_minor.positive?
    errors << "Choose who paid" if params[:payer_id].blank?
    errors << "Choose who was paid" if params[:recipient_id].blank?
    errors << "A settlement needs two different people" if params[:payer_id].present? &&
                                                           params[:payer_id].to_s == params[:recipient_id].to_s
  end

  def apply_attributes(settlement)
    settlement.assign_attributes(
      payer_id: params[:payer_id],
      recipient_id: params[:recipient_id],
      currency_code: currency.code,
      amount_minor: amount_minor,
      base_currency_code: base_currency.code,
      exchange_rate: conversion.rate,
      base_amount_minor: conversion.amount_minor,
      settled_on: settled_on,
      payment_method: params[:payment_method].presence,
      note: params[:note].presence
    )
  end
end
