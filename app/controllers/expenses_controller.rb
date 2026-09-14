# frozen_string_literal: true

# Handles group expenses and personal ones through the same path. A blank
# expense[group_id] means the expense belongs to the person, not a group.
class ExpensesController < ApplicationController
  before_action :load_expense, only: %i[show edit update void restore destroy]

  def index
    @filter = expense_filter
    @dashboard = DashboardCalculator.new(current_user)
    @expenses = ExpenseQuery.new(@dashboard.visible_expenses.involving(current_user.id), filter: @filter).call
                            .recent_first
                            .includes(:category, :currency, :base_currency, :group,
                                      expense_payers: :user, expense_splits: :user)
                            .limit(200)

    @timeline = Timeline.new(
      expenses: @expenses,
      settlements: Settlement.active.involving(current_user.id)
                             .recent_first.limit(50)
                             .includes(:payer, :recipient, :currency, :group),
      include_settlements: Timeline.settlements_relevant?(@filter)
    )
  end

  def show
    @revisions = @expense.revisions.recent_first.includes(:actor)
  end

  def new
    redirect_to root_path
  end

  def edit; end

  def create
    result = ExpenseCreator.call(**writer_args, actor: current_user, params: expense_params)

    if result.success?
      redirect_to destination_for(result.expense), notice: "#{result.expense.description} added."
    else
      redirect_back fallback_location: root_path, alert: result.errors.to_sentence
    end
  end

  def update
    result = ExpenseUpdater.call(expense: @expense, actor: current_user, params: expense_params)

    if result.success?
      redirect_to expense_path(@expense), notice: "Expense updated."
    else
      redirect_to edit_expense_path(@expense), alert: result.errors.to_sentence
    end
  end

  def void
    result = ExpenseVoider.new(expense: @expense, actor: current_user, reason: params[:reason]).call
    redirect_to expense_path(@expense),
                notice: result.success? ? "Expense voided. It stays in the history." : nil,
                alert: result.errors.first
  end

  def restore
    result = ExpenseVoider.new(expense: @expense, actor: current_user).restore
    redirect_to expense_path(@expense),
                notice: result.success? ? "Expense restored." : nil,
                alert: result.errors.first
  end

  def destroy
    redirect_to expense_path(@expense),
                alert: "Expenses are voided rather than deleted, so the history stays intact."
  end

  private

  # Only expenses in the viewer's groups, or their own personal ones.
  def load_expense
    @expense = Expense.where(group_id: current_user.groups.select(:id))
                      .or(Expense.where(group_id: nil, owner_id: current_user.id))
                      .includes(:group, :category, :currency, :base_currency,
                                expense_payers: :user, expense_splits: :user,
                                expense_participants: :user)
                      .find(params[:id])
  end

  def writer_args
    group = current_user.groups.find_by(id: expense_params[:group_id].presence)
    group ? { group: } : { owner: current_user }
  end

  def destination_for(expense)
    expense.group ? expenses_for_group_path(expense.group) : expenses_path
  end

  def expense_params
    params.require(:expense).permit(
      :group_id, :description, :notes, :category_id, :currency_code, :amount,
      :spent_on, :spent_time, :split_method, :exchange_rate,
      payers: %i[user_id amount], participants: %i[user_id split_value]
    )
  end
end
