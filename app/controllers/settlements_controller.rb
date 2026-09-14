# frozen_string_literal: true

class SettlementsController < ApplicationController
  before_action :load_group
  before_action :load_settlement, only: %i[edit update void]

  def index
    @settlements = @group.settlements.recent_first.includes(:payer, :recipient, :currency, :created_by)
    @calculator = BalanceCalculator.new(@group)
  end

  def new
    @calculator = BalanceCalculator.new(@group)
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

  def load_settlement
    @settlement = @group.settlements.find(params[:id])
  end

  def settlement_params
    params.require(:settlement).permit(:payer_id, :recipient_id, :currency_code, :amount,
                                       :settled_on, :payment_method, :note, :exchange_rate,
                                       :settles_currency_code)
  end
end
