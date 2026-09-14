# frozen_string_literal: true

# Accepting an invitation. This is the only way an account is created.
class SignupsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_user

  layout "plain"

  before_action :load_invitation

  def new
    @user = User.new
  end

  def create
    @user = User.new(signup_params)

    if @user.save
      # The signup form asked for an email already; don't ask again straight away.
      session[:email_prompt_shown] = true
      join_group
      @invitation.increment!(:accepted_count)
      sign_in(@user)

      ActivityRecorder.record(action: "user.joined",
                              summary: "#{@user.name} joined Onera",
                              actor: @user, subject: @user,
                              group: @invitation.group)

      redirect_to after_signup_path, notice: "Welcome to Onera, #{@user.name.split.first}."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def load_invitation
    @invitation = Invitation.live.find_by(token: params[:token])
    return if @invitation

    redirect_to new_user_session_path,
                alert: "That invite link isn't valid any more. Ask whoever sent it for a new one."
  end

  def join_group
    group = @invitation.group
    return if group.nil? || @user.member_of?(group)

    GroupMembership.create!(group:, user: @user)
    ActivityRecorder.record(action: "membership.created",
                            summary: "#{@user.name} joined #{group.name} by invite",
                            group:, actor: @user, subject: @user)
    Notifier.deliver(user: @invitation.created_by, actor: @user, group:, subject: group,
                     kind: "group.added",
                     title: "#{@user.name} joined #{group.name}",
                     body: "They used your invite link.",
                     url: group_memberships_path(group))
  end

  def after_signup_path
    @invitation.group ? group_path(@invitation.group) : root_path
  end

  def signup_params
    params.require(:user).permit(:name, :username, :email, :password, :password_confirmation,
                                 :preferred_currency_code)
  end
end
