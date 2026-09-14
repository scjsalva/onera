# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_current_user
  before_action :require_current_user

  # Every group and expense lookup is scoped to what the current user can see,
  # so a record that is missing and one that belongs to someone else fail the
  # same way - deliberately, since telling them apart would leak whether it
  # exists. Either way it is a dead end for this person, not an error.
  rescue_from ActiveRecord::RecordNotFound, with: :record_out_of_reach

  helper_method :current_user, :signed_in?, :current_groups, :contextual_group

  private

  def record_out_of_reach
    respond_to do |format|
      format.html do
        redirect_to root_path, alert: "That isn't available - it may have been removed, or it belongs to a group you're not in."
      end
      format.json { head :not_found }
      format.any  { head :not_found }
    end
  end

  # The single seam between "who is looking" and the rest of the app. Real
  # authentication would replace the body of this method and nothing else.
  def set_current_user
    Current.user = User.active.find_by(id: session[:current_user_id])
    session.delete(:current_user_id) if Current.user.nil?
  end

  def current_user = Current.user

  def signed_in? = Current.user.present?

  def require_current_user
    return if signed_in?

    session[:return_to] = request.fullpath if request.get?
    redirect_to user_selection_path
  end

  def current_groups
    @current_groups ||= current_user ? current_user.groups.active.ordered.to_a : []
  end

  def current_group
    @current_group ||= current_user.groups.find(params[:group_id] || params[:id])
  end

  # The group the page being rendered is about, if any. Used to preselect it
  # in the expense composer so adding several expenses to the same group
  # doesn't mean picking it every time.
  def contextual_group
    @group || @expense&.group
  end

  def expense_filter
    @expense_filter ||= ExpenseFilter.new(params)
  end
end
