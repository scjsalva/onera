# One polymorphic revision log rather than a table per record type: the shape
# is identical for expenses and settlements, and a single table keeps the
# "what happened to this financial record" query in one place.
class CreateRevisions < ActiveRecord::Migration[8.0]
  def change
    create_table :revisions do |t|
      t.references :revisable, polymorphic: true, null: false
      t.references :actor, foreign_key: { to_table: :users }
      t.integer :revision_number, null: false
      t.string :action, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.jsonb :changed_fields, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :revisions, %i[revisable_type revisable_id revision_number],
              unique: true, name: "index_revisions_on_revisable_and_number"
  end
end
