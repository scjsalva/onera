# frozen_string_literal: true

class InvitationsController < ApplicationController
  def index
    @invitation = Invitation.for(group: nil, creator: current_user)
  end

  def create
    group = current_user.groups.find(params[:group_id]) if params[:group_id].present?
    invitation = Invitation.for(group:, creator: current_user)
    invitation.revoke! if params[:refresh].present?
    invitation = Invitation.for(group:, creator: current_user) if params[:refresh].present?

    redirect_back fallback_location: invitations_path,
                  notice: params[:refresh].present? ? "New link created. The old one stopped working." : nil
  end
end
