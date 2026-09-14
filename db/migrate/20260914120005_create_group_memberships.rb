class CreateGroupMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :group_memberships do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :joined_at, null: false
      t.timestamps
    end

    add_index :group_memberships, %i[group_id user_id], unique: true
    add_index :group_memberships, %i[user_id group_id]
  end
end
