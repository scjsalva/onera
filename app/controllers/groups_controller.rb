# frozen_string_literal: true

class GroupsController < ApplicationController
  before_action :load_group, except: %i[index new create]
  before_action :load_balances, only: %i[show balances]

  def index
    @dashboard = DashboardCalculator.new(current_user)
    @summaries = @dashboard.group_summaries
  end

  def new
    @group = Group.new(base_currency_code: current_user.preferred_currency_code)
  end

  def create
    @group = Group.new(group_params.merge(created_by: current_user))

    if @group.save
      GroupMembership.create!(group: @group, user: current_user)
      Array(params[:member_ids]).reject(&:blank?).uniq.each do |user_id|
        next if user_id.to_i == current_user.id

        GroupMembership.find_or_create_by!(group: @group, user_id: user_id)
      end

      ActivityRecorder.record(action: "group.created", summary: "#{current_user.name} created #{@group.name}",
                              group: @group, actor: current_user, subject: @group)
      redirect_to @group, notice: "#{@group.name} is ready."
    else
      flash.now[:alert] = @group.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @recent_expenses = group_expenses.recent_first.limit(6)
    @recent_settlements = @group.settlements.active.recent_first.limit(4).includes(:payer, :recipient, :currency)
    @pending_rates = RateLocker.pending_for(@group)
  end

  def expenses
    @filter = expense_filter
    @expenses = ExpenseQuery.new(@group.expenses, filter: @filter).call
                            .recent_first
                            .includes(:category, :currency, :base_currency, :group,
                                      expense_payers: :user, expense_splits: :user)
  end

  def balances
    @pending_rates = RateLocker.pending_for(@group)
  end

  def activity
    @events = @group.activity_events.recent_first.limit(80).includes(:actor)
  end

  def edit; end

  def update
    if @group.update(group_params)
      redirect_to @group, notice: "Group updated."
    else
      flash.now[:alert] = @group.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @group.expenses.exists? || @group.settlements.exists?
      @group.update!(archived_at: Time.current)
      redirect_to groups_path, notice: "#{@group.name} was archived. Its records are kept."
    else
      name = @group.name
      @group.destroy!
      redirect_to groups_path, notice: "#{name} was deleted."
    end
  end

  private

  def load_group
    @group = current_user.groups.find(params[:id])
  end

  def load_balances
    @calculator = BalanceCalculator.new(@group)
  end

  def group_expenses
    @group.expenses.active.includes(:category, :currency, :base_currency, :group,
                                    expense_payers: :user, expense_splits: :user)
  end

  def group_params
    params.require(:group).permit(:name, :description, :base_currency_code)
  end
end
