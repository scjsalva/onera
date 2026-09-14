# frozen_string_literal: true

class GroupsController < ApplicationController
  before_action :load_group, except: %i[index new create]
  before_action :load_balances, only: %i[show balances]

  def index
    @dashboard = DashboardCalculator.new(current_user)
    @summaries = @dashboard.group_summaries
    @archived = current_user.groups.where.not(archived_at: nil).ordered
  end

  def new
    @group = Group.new(base_currency_code: current_user.preferred_currency_code)
  end

  def create
    @group = Group.new(group_params.merge(created_by: current_user))

    if @group.save
      GroupMembership.create!(group: @group, user: current_user)
      friend_ids = current_user.friends.ids.to_set
      Array(params[:member_ids]).reject(&:blank?).uniq.each do |user_id|
        next if user_id.to_i == current_user.id
        next unless friend_ids.include?(user_id.to_i)

        membership = GroupMembership.find_or_create_by!(group: @group, user_id: user_id)
        Notifier.added_to_group(membership.user, group: @group, actor: current_user)
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

    @timeline = Timeline.new(
      expenses: @expenses,
      settlements: @group.settlements.active.recent_first.includes(:payer, :recipient, :currency),
      include_settlements: Timeline.settlements_relevant?(@filter)
    )
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

  # Hidden, not deleted. Everything stays; the group just stops taking new
  # entries and drops out of what you are owed.
  def archive
    return redirect_to @group, alert: "That group is already archived." if @group.archived?

    @group.update!(archived_at: Time.current)
    record_and_notify(:archived)

    redirect_to groups_path,
                notice: "#{@group.name} is archived. Nothing was deleted - you can reopen it any time."
  end

  def restore
    return redirect_to @group, alert: "That group is not archived." unless @group.archived?

    @group.update!(archived_at: nil)
    record_and_notify(:restored)

    redirect_to @group, notice: "#{@group.name} is active again."
  end

  def destroy
    if @group.expenses.exists? || @group.settlements.exists?
      # A group with money in it is never destroyed, whatever was clicked.
      @group.update!(archived_at: Time.current)
      record_and_notify(:archived)
      redirect_to groups_path, notice: "#{@group.name} was archived. Its records are kept."
    else
      name = @group.name
      @group.destroy!
      redirect_to groups_path, notice: "#{name} was deleted. It had nothing in it."
    end
  end

  private

  def record_and_notify(action)
    summary = action == :archived ? "#{current_user.name} archived #{@group.name}"
                                  : "#{current_user.name} reopened #{@group.name}"
    ActivityRecorder.record(action: "group.#{action}", summary:, group: @group,
                            actor: current_user, subject: @group)

    @group.users.each do |member|
      Notifier.deliver(
        user: member, actor: current_user, group: @group, subject: @group,
        kind: "group.#{action}",
        title: summary,
        body: action == :archived ? "It stops taking new expenses, and its balances leave your totals."
                                  : "It takes expenses again, and its balances are back in your totals.",
        url: Rails.application.routes.url_helpers.group_path(@group)
      )
    end
  end

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
