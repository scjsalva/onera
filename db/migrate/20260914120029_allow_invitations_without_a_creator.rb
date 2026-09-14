# frozen_string_literal: true

# A fresh deployment has nobody in it, and an invitation needed a member to
# have created it - so the only way in was a shell on the server. An invitation
# without a referrer is the way the first person gets an account.
class AllowInvitationsWithoutACreator < ActiveRecord::Migration[8.0]
  def change
    change_column_null :invitations, :created_by_id, true
  end
end
