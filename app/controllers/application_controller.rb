# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!
  before_action :set_current_user
  before_action :ask_for_email

  # Every group and expense lookup is scoped to what the current user can see,
  # so a record that is missing and one that belongs to someone else fail the
  # same way - deliberately, since telling them apart would leak whether it
  # exists. Either way it is a dead end for this person, not an error.
  rescue_from ActiveRecord::RecordNotFound, with: :record_out_of_reach

  helper_method :current_groups, :contextual_group

  # Turbo re-issues the original method when a form's redirect comes back as
  # 302, which turns a redirect after a DELETE into a second DELETE. 303 tells
  # it to follow with GET. Doing it here rather than adding status: :see_other
  # to sixty call sites.
  def redirect_to(options = {}, response_options = {})
    response_options[:status] ||= :see_other unless request.get? || request.head?
    super
  end

  private

  # Sign-in accepts a username or an email through one field, so Devise has
  # to be told that :login is a permitted parameter.
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :login, :remember_me ])
  end

  def record_out_of_reach
    respond_to do |format|
      format.html do
        redirect_to root_path, alert: "That isn't available - it may have been removed, or it belongs to a group you're not in."
      end
      format.json { head :not_found }
      format.any  { head :not_found }
    end
  end

  # The single seam between "who is looking" and the rest of the app. It used
  # to read a session-selected id; now Devise supplies it. Nothing downstream
  # changed, which was the point of routing everything through Current.user.
  def set_current_user
    Current.user = warden.user
  end

  # Interrupts once per sign-in, and only once. Email stays optional for using
  # the app but is the only way to recover an account, so the ask returns on
  # the next sign-in - it just doesn't follow you around this one. Marking it
  # shown before redirecting is what keeps it from re-catching every page
  # someone navigates to instead of answering.
  def ask_for_email
    return unless Current.user
    return if Current.user.email.present?
    return if session[:email_prompt_shown]
    # HEAD is routed like GET but request.get? is false for it, and either way
    # only a page load should be interrupted.
    return unless request.get? || request.head?
    return if request.xhr? || !request.format.html?
    return if controller_name.in?(%w[emails sessions signups])

    session[:email_prompt_shown] = true
    redirect_to edit_email_path
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
