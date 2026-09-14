# Sixteen colours now: eight deep ones that carry white initials and eight
# pale ones that need dark initials.
class WidenAvatarToneRange < ActiveRecord::Migration[8.0]
  def change
    remove_check_constraint :users, name: "users_avatar_tone_range"
    add_check_constraint :users, "avatar_tone IS NULL OR (avatar_tone >= 1 AND avatar_tone <= 16)",
                         name: "users_avatar_tone_range"
  end
end
