class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.text :description
      t.string :base_currency_code, limit: 3, null: false, default: "PHP"
      t.references :created_by, foreign_key: { to_table: :users }, index: true
      t.datetime :archived_at
      t.timestamps
    end

    add_foreign_key :groups, :currencies, column: :base_currency_code, primary_key: :code
    add_index :groups, :base_currency_code
    add_check_constraint :groups, "length(btrim(name)) > 0", name: "groups_name_present"
  end
end
