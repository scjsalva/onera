class CreateExpenseParticipants < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_participants do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      # The raw input for the expense's split method: a percentage, an exact
      # amount in minor units, or a share count. Null for an equal split.
      t.decimal :split_value, precision: 20, scale: 6
      t.timestamps
    end

    add_index :expense_participants, %i[expense_id user_id], unique: true
    add_index :expense_participants, %i[user_id expense_id]
    add_check_constraint :expense_participants, "split_value IS NULL OR split_value >= 0",
                         name: "expense_participants_split_value_non_negative"
  end
end
