class CreateExpenseSplits < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_splits do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      # Server-computed. Guaranteed to sum exactly to the expense total.
      t.bigint :amount_minor, null: false
      t.bigint :base_amount_minor, null: false
      t.timestamps
    end

    add_index :expense_splits, %i[expense_id user_id], unique: true
    add_index :expense_splits, %i[user_id expense_id]
    add_check_constraint :expense_splits, "amount_minor >= 0", name: "expense_splits_amount_non_negative"
  end
end
