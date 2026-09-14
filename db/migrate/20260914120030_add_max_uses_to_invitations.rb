# frozen_string_literal: true

# A link that anyone who finds the sign-in page can use needs a way to stop.
# Null means unlimited, which is what a member's own invite link stays.
class AddMaxUsesToInvitations < ActiveRecord::Migration[8.0]
  def change
    add_column :invitations, :max_uses, :integer
    add_check_constraint :invitations, "max_uses IS NULL OR max_uses > 0", name: "invitations_max_uses_positive"
  end
end
