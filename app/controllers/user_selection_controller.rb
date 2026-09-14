# frozen_string_literal: true

# The temporary "who are you?" flow. Deliberately not authentication: no
# password, no PIN, no verification. Switching only changes whose perspective
# the app is rendered from - it never touches financial records.
class UserSelectionController < ApplicationController
  skip_before_action :require_current_user

  layout "plain"

  def new
    @users = User.active.ordered
  end

  def create
    user = User.active.find_by(id: params[:user_id])

    if user.nil?
      redirect_to user_selection_path, alert: "Pick who you are to continue."
      return
    end

    session[:current_user_id] = user.id
    redirect_to session.delete(:return_to) || root_path, notice: "You're viewing Onera as #{user.name}."
  end

  def destroy
    session.delete(:current_user_id)
    redirect_to user_selection_path, notice: "Pick who you are to continue."
  end
end
