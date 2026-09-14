# frozen_string_literal: true

class InvitationsController < ApplicationController
  def index
    @invitation = Invitation.for(group: nil, creator: current_user)
  end

  # Replacing a link revokes the old one first, so the previous URL stops
  # working the moment a new one is handed out.
  def create
    group = current_user.groups.find(params[:group_id]) if params[:group_id].present?

    if params[:refresh].present?
      Invitation.live.where(group:, created_by: current_user).find_each(&:revoke!)
      Invitation.for(group:, creator: current_user)
      notice = "New link created. The old one stopped working."
    else
      Invitation.for(group:, creator: current_user)
    end

    redirect_back fallback_location: invitations_path, notice: notice
  end
end
