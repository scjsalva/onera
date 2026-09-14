# frozen_string_literal: true

class SettlementsController < ApplicationController
  before_action :load_group
  before_action :refuse_when_archived, only: %i[new create edit update void]
  before_action :load_settlement, only: %i[edit update void]

  def index
    @settlements = @group.settlements.recent_first.includes(:payer, :recipient, :currency, :created_by)
    @calculator = BalanceCalculator.new(@group)
  end

  def new
    @calculator = BalanceCalculator.new(@group)
    @settlement = @group.settlements.new(
      payer_id: params[:payer_id].presence || current_user.id,
      recipient_id: params[:recipient_id].presence,
      currency_code: params[:currency_code].presence || @group.base_currency_code,
      settled_on: Date.current
    )
    @prefill_amount = params[:amount].presence
  end

  def create
    result = SettlementCreator.call(group: @group, actor: current_user, params: settlement_params)

    if result.success?
      redirect_to group_settlements_path(@group), notice: "Payment recorded."
    else
      redirect_back fallback_location: group_settlements_path(@group), alert: result.errors.to_sentence
    end
  end

  def edit; end

  def update
    result = SettlementUpdater.call(settlement: @settlement, actor: current_user, params: settlement_params)

    if result.success?
      redirect_to group_settlements_path(@group), notice: "Payment updated."
    else
      redirect_to edit_group_settlement_path(@group, @settlement), alert: result.errors.to_sentence
    end
  end

  def void
    result = SettlementVoider.call(settlement: @settlement, actor: current_user)
    redirect_to group_settlements_path(@group),
                notice: result.success? ? "Payment voided. It stays in the history." : nil,
                alert: result.errors.first
  end

  private

  def load_group
    @group = current_user.groups.find(params[:group_id])
  end

  # An archived group is a record of what happened, not somewhere to keep
  # recording.
  def refuse_when_archived
    return unless @group.archived?

    redirect_to group_path(@group),
                alert: "#{@group.name} is archived. Reopen it from its settings to record payments."
  end

  def load_settlement
    @settlement = @group.settlements.find(params[:id])
  end

  def settlement_params
    params.require(:settlement).permit(:payer_id, :recipient_id, :currency_code, :amount,
                                       :settled_on, :payment_method, :note, :exchange_rate,
                                       :settles_currency_code)
  end
end
