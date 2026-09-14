# frozen_string_literal: true

module Api
  # Powers the live preview in the expense form.
  #
  # The preview is computed by the same SplitCalculator that persists the real
  # figures, so what the form shows is what will be saved - but it is still
  # only a preview. Submitting recalculates everything from scratch and the
  # client's numbers are discarded.
  class SplitPreviewsController < BaseController
    def create
      group = current_user.groups.find_by(id: preview_params[:group_id])
      currency = Currency.active.find_by(code: preview_params[:currency_code]) || current_user.preferred_currency
      target = group ? group.base_currency : current_user.preferred_currency

      total = MoneyAmount.from_major(preview_params[:amount].presence || 0, currency)
      result = SplitCalculator.new(
        total_minor: total.minor,
        split_method: preview_params[:split_method].presence || "equal",
        participants: participants,
        currency:
      ).call

      render json: {
        valid: result.valid? && payer_error.nil?,
        errors: (result.errors + [ payer_error ]).compact,
        total: money_json(total),
        splits: result.allocations.map { |user_id, minor| { user_id:, **money_json(MoneyAmount.new(minor, currency)) } },
        conversion: conversion_json(total, currency, target)
      }
    end

    private

    def preview_params
      params.permit(:group_id, :amount, :currency_code, :split_method,
                    participants: %i[user_id split_value], payers: %i[user_id amount])
    end

    def rows(value)
      case value
      when nil then []
      when Array then value
      else value.respond_to?(:values) ? value.values : Array(value)
      end
    end

    def participants
      rows(preview_params[:participants]).filter_map do |row|
        next if row[:user_id].blank?

        { user_id: row[:user_id].to_i, value: row[:split_value] }
      end
    end

    def payer_error
      currency = Currency.active.find_by(code: preview_params[:currency_code]) || current_user.preferred_currency
      paid_rows = rows(preview_params[:payers]).filter_map do |row|
        next if row[:user_id].blank?

        MoneyAmount.from_major(row[:amount].presence || 0, currency).minor
      end
      return nil if paid_rows.empty?

      total = MoneyAmount.from_major(preview_params[:amount].presence || 0, currency)
      paid = paid_rows.sum
      return nil if paid == total.minor

      "Payers add up to #{MoneyAmount.new(paid, currency).format} of #{total.format}"
    end

    # The guide figure shown under the amount. Explicitly an estimate: the rate
    # that the money follows is chosen later, at settle-up.
    def conversion_json(total, currency, target)
      return { applicable: false } if currency.code == target.code || total.minor.zero?

      converted = CurrencyConverter.call(amount_minor: total.minor, from: currency, to: target)
      {
        applicable: true,
        estimated: true,
        rate: converted.rate.to_s("F"),
        target: CurrencyPresenter.new(target).as_json,
        amount: money_json(MoneyAmount.new(converted.amount_minor, target))
      }
    rescue ArgumentError
      { applicable: true, estimated: true, unavailable: true, target: CurrencyPresenter.new(target).as_json }
    end
  end
end
