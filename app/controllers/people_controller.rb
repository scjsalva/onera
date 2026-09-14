# frozen_string_literal: true

# Creating a new global person. A User is created once and then referenced
# from every group they join - adding someone to a group never duplicates them.
class PeopleController < ApplicationController
  def new
    @user = User.new(preferred_currency_code: "PHP")
    @group = current_user.groups.find_by(id: params[:group_id])
  end

  def create
    @user = User.new(person_params)
    @group = current_user.groups.find_by(id: params[:group_id])

    if @user.save
      ActivityRecorder.record(
        action: "user.created",
        summary: "#{current_user.name} added #{@user.name} to Onera",
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
        redirect_to root_path, notice: "#{@user.name} was added."
      end
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def person_params
    params.require(:user).permit(:name, :email, :date_of_birth, :preferred_currency_code)
  end
end
