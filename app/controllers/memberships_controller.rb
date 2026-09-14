# frozen_string_literal: true

class MembershipsController < ApplicationController
  before_action :load_group

  def index
    @memberships = @group.group_memberships.ordered.includes(:user)
    @calculator = BalanceCalculator.new(@group)
    @candidates = User.active.ordered.where.not(id: @group.group_memberships.select(:user_id))
    @invitation = Invitation.for(group: @group, creator: current_user)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          members: UserPresenter.collection(@group.users.ordered),
          base_currency: @group.base_currency_code
        }
      end
    end
  end

  def create
    users = User.active.where(id: Array(params[:user_ids]).reject(&:blank?))
    added = users.reject { |user| user.member_of?(@group) }

    added.each do |user|
      GroupMembership.create!(group: @group, user:)
      ActivityRecorder.record(action: "membership.created",
                              summary: "#{current_user.name} added #{user.name} to #{@group.name}",
                              group: @group, actor: current_user, subject: user)
      Notifier.added_to_group(user, group: @group, actor: current_user)
    end

    redirect_to group_memberships_path(@group),
                notice: added.any? ? "#{added.map(&:name).to_sentence} joined #{@group.name}." : "Nobody new to add."
  end

  def destroy
    membership = @group.group_memberships.find(params[:id])
    user = membership.user

    if involved?(user)
      redirect_to group_memberships_path(@group),
                  alert: "#{user.name} has expenses or settlements here, so they can't be removed."
      return
    end

    membership.destroy!
    ActivityRecorder.record(action: "membership.removed",
                            summary: "#{current_user.name} removed #{user.name} from #{@group.name}",
                            group: @group, actor: current_user, subject: user)
    Notifier.removed_from_group(user, group: @group, actor: current_user)
    redirect_to group_memberships_path(@group), notice: "#{user.name} was removed."
  end

  private

  def load_group
    @group = current_user.groups.find(params[:group_id])
  end

  # Removing someone who appears in the ledger would orphan financial records,
  # so it is refused rather than cascaded.
  def involved?(user)
    ExpensePayer.joins(:expense).where(user:, expenses: { group_id: @group.id }).exists? ||
      ExpenseSplit.joins(:expense).where(user:, expenses: { group_id: @group.id }).exists? ||
      @group.settlements.involving(user.id).exists?
  end
end
