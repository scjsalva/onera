# frozen_string_literal: true

# Creating a new global person. A User is created once and then referenced
# from every group they join - adding someone to a group never duplicates them.
class PeopleController < ApplicationController
  # Reachable from the user picker, before anyone has been selected. Without
  # this the "Add someone new" link redirected straight back to the picker.
  skip_before_action :require_current_user, only: %i[new create]

  def index
    @people = User.ordered.includes(:groups)
  end

  def new
    @user = User.new(preferred_currency_code: "PHP")
    @group = current_user&.groups&.find_by(id: params[:group_id])
  end

  def create
    @user = User.new(person_params)
    @group = current_user&.groups&.find_by(id: params[:group_id])

    if @user.save
      ActivityRecorder.record(
        action: "user.created",
        summary: current_user ? "#{current_user.name} added #{@user.name} to Onera" : "#{@user.name} joined Onera",
        actor: current_user, subject: @user
      )

      if @group
        GroupMembership.create!(group: @group, user: @user)
        ActivityRecorder.record(
          action: "membership.created",
          summary: "#{current_user.name} added #{@user.name} to #{@group.name}",
          group: @group, actor: current_user, subject: @user
        )
        redirect_to group_memberships_path(@group), notice: "#{@user.name} joined #{@group.name}."
      else
        redirect_to after_create_path, notice: "#{@user.name} was added."
      end
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Created from the picker, before anyone is signed in: go back there so the
  # new person can be chosen. Otherwise stay in the app.
  def after_create_path
    signed_in? ? people_path : user_selection_path
  end

  def person_params
    params.require(:user).permit(:name, :email, :date_of_birth, :preferred_currency_code)
  end
end
