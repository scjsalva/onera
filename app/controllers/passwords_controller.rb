# frozen_string_literal: true

# Changing your password while signed in. Requires the current one, so a
# borrowed session can't lock the owner out.
class PasswordsController < ApplicationController
  def edit; end

  def update
    unless current_user.valid_password?(params[:current_password].to_s)
      flash.now[:alert] = "That isn't your current password."
      return render :edit, status: :unprocessable_entity
    end

    if params[:password].to_s.length < 8
      flash.now[:alert] = "Your new password needs at least 8 characters."
      return render :edit, status: :unprocessable_entity
    end

    if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      bypass_sign_in(current_user)
      ActivityRecorder.record(action: "user.password_changed",
                              summary: "#{current_user.name} changed their password",
                              actor: current_user, subject: current_user)
      redirect_to profile_path, notice: "Password changed."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end
end
