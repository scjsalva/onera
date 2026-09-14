# People should be able to change their face. The style is one of a handful of
# sets from the avatar service; the seed is what makes two people with the same
# style look different, and re-rolling it is how you get a new face without
# changing your name.
class AddAvatarChoiceToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :avatar_style, :string, null: false, default: "notionists-neutral"
    add_column :users, :avatar_seed, :string
  end
end
