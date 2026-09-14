# frozen_string_literal: true

# Changing your face. The style is one of a fixed set, the colour one of
# eight, and re-rolling changes the seed - which is what makes two people with
# the same style look different.
class AvatarsController < ApplicationController
  def update
    style = params[:avatar_style].presence
    tone = params[:avatar_tone].presence

    current_user.avatar_style = style if style && User::AVATAR_STYLES.key?(style)
    current_user.avatar_tone = tone.to_i if tone && User::AVATAR_TONES.include?(tone.to_i)

    if current_user.save
      redirect_to edit_profile_path, notice: "Avatar updated."
    else
      redirect_to edit_profile_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  def shuffle
    current_user.reroll_avatar!
    redirect_to edit_profile_path, notice: "New avatar."
  end
end
