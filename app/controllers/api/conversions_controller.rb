# frozen_string_literal: true

module Api
  # Used by the settle-up rate editor to show what a rate does to a total
  # before it is committed.
  class ConversionsController < BaseController
    def show
      from = Currency.find_by(code: params[:from])
      to = Currency.find_by(code: params[:to])
      return render json: { error: "Unknown currency" }, status: :unprocessable_entity if from.nil? || to.nil?

      amount = MoneyAmount.from_major(params[:amount].presence || 0, from)
      result = CurrencyConverter.call(amount_minor: amount.minor, from:, to:, rate: params[:rate].presence)

      render json: { rate: result.rate.to_s("F"), amount: money_json(MoneyAmount.new(result.amount_minor, to)) }
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
