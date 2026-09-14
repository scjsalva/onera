# The background colour behind an avatar. Left null it is derived from the
# user id, which is what gave everyone a distinct colour before anyone could
# choose one.
class AddAvatarToneToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :avatar_tone, :integer
    add_check_constraint :users, "avatar_tone IS NULL OR (avatar_tone >= 1 AND avatar_tone <= 8)",
                         name: "users_avatar_tone_range"
  end
end
