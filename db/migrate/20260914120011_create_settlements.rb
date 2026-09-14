class CreateSettlements < ActiveRecord::Migration[8.0]
  def change
    create_table :settlements do |t|
      t.references :group, null: false, foreign_key: true
      t.references :payer, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :created_by, foreign_key: { to_table: :users }

      t.string :currency_code, limit: 3, null: false
      t.bigint :amount_minor, null: false
      t.string :base_currency_code, limit: 3, null: false
      t.decimal :exchange_rate, precision: 24, scale: 12, null: false, default: 1
      t.bigint :base_amount_minor, null: false

      t.date :settled_on, null: false
      t.string :payment_method
      t.text :note

      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }

      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_foreign_key :settlements, :currencies, column: :currency_code, primary_key: :code
    add_foreign_key :settlements, :currencies, column: :base_currency_code, primary_key: :code

    add_index :settlements, %i[group_id settled_on]
    add_index :settlements, %i[payer_id recipient_id]
    add_index :settlements, :settled_on
    add_index :settlements, :voided_at

    add_check_constraint :settlements, "amount_minor > 0", name: "settlements_amount_positive"
    add_check_constraint :settlements, "base_amount_minor > 0", name: "settlements_base_amount_positive"
    add_check_constraint :settlements, "exchange_rate > 0", name: "settlements_rate_positive"
    add_check_constraint :settlements, "payer_id <> recipient_id", name: "settlements_distinct_parties"
  end
end
