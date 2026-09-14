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

  # Deleting yourself anonymizes and archives; it never destroys the record,
  # because expenses and settlements point at it.
  def destroy
    result = UserAnonymizer.call(user: current_user, actor: current_user)

    if result.success?
      session.delete(:current_user_id)
      redirect_to user_selection_path,
                  notice: "Your profile was removed. Your expenses and payments are untouched."
    else
      redirect_to edit_profile_path, alert: result.errors.to_sentence
    end
  end

  private

  # What this person would be called once anonymized, so the confirmation can
  # show it rather than describe it.
  def next_archived_label
    "Removed person #{(User.archived.maximum(:archived_ordinal) || 0) + 1}"
  end
  helper_method :next_archived_label

  def profile_params
    params.require(:user).permit(:name, :email, :date_of_birth, :preferred_currency_code)
  end
end
