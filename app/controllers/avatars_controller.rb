# frozen_string_literal: true

# Changing your face. The style is one of a fixed set; re-rolling changes the
# seed, which is what makes two people with the same style look different.
class AvatarsController < ApplicationController
  def update
    style = params[:avatar_style].to_s

    if User::AVATAR_STYLES.key?(style)
      current_user.update!(avatar_style: style)
      redirect_to edit_profile_path, notice: "Avatar updated."
    else
      redirect_to edit_profile_path, alert: "That isn't one of the avatar styles."
    end
  end

  def shuffle
    current_user.reroll_avatar!
    redirect_to edit_profile_path, notice: "New avatar."
  end
end
