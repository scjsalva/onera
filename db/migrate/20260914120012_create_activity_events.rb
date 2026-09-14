class CreateActivityEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_events do |t|
      t.references :group, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :subject, polymorphic: true
      t.string :action, null: false
      t.string :summary, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :activity_events, %i[group_id occurred_at]
    add_index :activity_events, :occurred_at
    add_index :activity_events, :action
  end
end
