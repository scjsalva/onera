class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email
      t.date :date_of_birth
      t.timestamps
    end

    add_index :users, "lower(email)", unique: true, where: "email IS NOT NULL",
              name: "index_users_on_lower_email"
    add_check_constraint :users, "length(btrim(name)) > 0", name: "users_name_present"
  end
end
