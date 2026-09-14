# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_current_user
  before_action :require_current_user

  helper_method :current_user, :signed_in?, :current_groups

  private

  # The single seam between "who is looking" and the rest of the app. Real
  # authentication would replace the body of this method and nothing else.
  def set_current_user
    Current.user = User.find_by(id: session[:current_user_id])
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

  def expense_filter
    @expense_filter ||= ExpenseFilter.new(params)
  end
end
