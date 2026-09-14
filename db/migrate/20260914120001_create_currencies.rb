class CreateCurrencies < ActiveRecord::Migration[8.0]
  def change
    create_table :currencies, id: false do |t|
      t.string :code, limit: 3, null: false, primary_key: true
      t.string :name, null: false
      t.string :symbol, null: false
      # Number of decimal places. JPY/KRW are zero-decimal; everything is
      # stored as an integer count of minor units, so this drives all maths.
      t.integer :exponent, null: false, default: 2
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 100
      t.timestamps
    end

    add_index :currencies, :active
    add_check_constraint :currencies, "exponent >= 0 AND exponent <= 4", name: "currencies_exponent_range"
    add_check_constraint :currencies, "code = upper(code)", name: "currencies_code_uppercase"
  end
end
