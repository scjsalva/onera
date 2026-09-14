# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @dashboard = DashboardCalculator.new(current_user)
  end

  def edit; end

  def update
    if current_user.update(profile_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email, :date_of_birth, :preferred_currency_code)
  end
end
