# frozen_string_literal: true

# The settle-up flow, where the one conversion that matters is chosen.
#
# Two ways out of a multi-currency group:
#   - pay each currency separately, leaving every ledger in its own currency;
#   - or consolidate into one currency, which locks a rate per currency onto
#     the underlying expenses and collapses the balances into a single figure.
#
# Consolidating is optional. Nothing is converted until somebody asks for it.
class SettleUpsController < ApplicationController
  before_action :load_group

  def show
    @calculator = BalanceCalculator.new(@group)
    @target_currency = target_currency
    @pending_rates = RateLocker.pending_for(@group, target_currency: @target_currency)
    @consolidation = @calculator.consolidated(@target_currency, rates: submitted_rates)
    @active_currencies = @calculator.currencies.select { |currency| @calculator.active_in?(currency.code) }
  end

  def create
    result = RateLocker.call(group: @group, actor: current_user,
                             rates: submitted_rates, target_currency: target_currency)

    if result.success?
      redirect_to balances_for_group_path(@group),
                  notice: "Converted #{result.locked_count} #{'expense'.pluralize(result.locked_count)} " \
                          "into #{target_currency.code}. Those rates are now locked in."
    else
      redirect_to group_settle_up_path(@group, currency: target_currency.code), alert: result.errors.to_sentence
    end
  end

  private

  def load_group
    @group = current_user.groups.find(params[:group_id])
  end

  # Defaults to the group's currency, but the person settling can pick another
  # one right here - that is the point of the step.
  def target_currency
    Currency.active.find_by(code: params[:currency].presence || params.dig(:settle_up, :currency)) ||
      @group.base_currency
  end

  def submitted_rates
    rates = params[:rates]
    return {} if rates.blank?

    rates = rates.to_unsafe_h if rates.respond_to?(:to_unsafe_h)
    rates.to_h.transform_keys(&:to_s)
  end
end
