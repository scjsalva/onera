class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.references :group, null: false, foreign_key: true
      t.references :category, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }

      t.string :description, null: false
      t.text :notes

      # Money is stored as integer minor units. Never floats.
      t.string :currency_code, limit: 3, null: false
      t.bigint :amount_minor, null: false

      # The group's base currency and the rate are snapshotted onto the record
      # so a later rate change or base-currency change cannot rewrite history.
      t.string :base_currency_code, limit: 3, null: false
      t.decimal :exchange_rate, precision: 24, scale: 12, null: false, default: 1
      t.bigint :base_amount_minor, null: false

      t.date :spent_on, null: false
      t.time :spent_time

      t.string :split_method, null: false, default: "equal"

      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.string :void_reason

      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :expenses, :currencies, column: :currency_code, primary_key: :code
    add_foreign_key :expenses, :currencies, column: :base_currency_code, primary_key: :code

    add_index :expenses, :spent_on
    add_index :expenses, :currency_code
    add_index :expenses, %i[group_id spent_on]
    add_index :expenses, %i[group_id voided_at]
    add_index :expenses, :voided_at

    add_check_constraint :expenses, "amount_minor > 0", name: "expenses_amount_positive"
    add_check_constraint :expenses, "base_amount_minor > 0", name: "expenses_base_amount_positive"
    add_check_constraint :expenses, "exchange_rate > 0", name: "expenses_rate_positive"
    add_check_constraint :expenses,
                         "split_method IN ('equal','percentage','fixed','shares')",
                         name: "expenses_split_method_valid"
    add_check_constraint :expenses, "length(btrim(description)) > 0", name: "expenses_description_present"
  end
end
