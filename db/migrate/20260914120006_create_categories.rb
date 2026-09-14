class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :icon, null: false, default: "receipt"
      t.string :color, null: false, default: "ink"
      t.integer :position, null: false, default: 100
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :active
  end
end
