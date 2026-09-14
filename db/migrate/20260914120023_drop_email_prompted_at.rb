# The email prompt now recurs once per sign-in until an email is given, so
# there is no permanent "already asked" state to remember.
class DropEmailPromptedAt < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :email_prompted_at, :datetime
  end
end
