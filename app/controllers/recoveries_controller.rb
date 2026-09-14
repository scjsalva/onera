# frozen_string_literal: true

# Forgotten-password flow, using a recovery code instead of an emailed link.
class RecoveriesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_user

  layout "plain"

  def new; end

  def create
    result = RecoveryCodeRedeemer.call(
      email: params[:email],
      code: params[:code],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )

    if result.success?
      sign_in(result.user)
      redirect_to root_path,
                  notice: "Password changed. #{helpers.pluralize(result.user.unused_recovery_codes, 'recovery code')} left."
    else
      @email = params[:email]
      flash.now[:alert] = result.errors.to_sentence
      render :new, status: :unprocessable_entity
    end
  end
end
