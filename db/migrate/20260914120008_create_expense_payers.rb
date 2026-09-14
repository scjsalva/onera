class CreateExpensePayers < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_payers do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.bigint :amount_minor, null: false
      t.bigint :base_amount_minor, null: false
      t.timestamps
    end

    add_index :expense_payers, %i[expense_id user_id], unique: true
    add_index :expense_payers, %i[user_id expense_id]
    add_check_constraint :expense_payers, "amount_minor > 0", name: "expense_payers_amount_positive"
  end
end
