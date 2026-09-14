# Per-person notifications.
#
# Distinct from activity_events: an activity event is a fact about a group,
# written once. A notification is addressed to one person, has a read state,
# and exists only for people the event actually affects - so one expense
# produces one event and several notifications.
class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :group, foreign_key: true
      t.references :subject, polymorphic: true

      t.string :kind, null: false
      t.string :title, null: false
      t.string :body
      t.string :url
      t.jsonb :metadata, null: false, default: {}
      t.datetime :read_at
      t.timestamps
    end

    add_index :notifications, %i[user_id read_at created_at], name: "index_notifications_on_user_and_state"
    add_index :notifications, %i[user_id created_at]
  end
end
