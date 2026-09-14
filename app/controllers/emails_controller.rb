# frozen_string_literal: true

# The email prompt. Email is optional for using Onera, but it is the only way
# to recover an account, so this is asked once per sign-in until it is given
# or the person declines for that session.
class EmailsController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    return redirect_to root_path if params[:skip].present?

    current_user.email = params.dig(:user, :email)

    if current_user.save
      redirect_to root_path, notice: "Email saved. You can now sign in with it and recover your account."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      @user = current_user
      render :edit, status: :unprocessable_entity
    end
  end
end
