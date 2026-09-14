# An expense does not have to belong to a group. A personal expense is owned
# by one person, shared with nobody, and denominated in their own primary
# currency - it feeds their spending totals but can never create a debt.
#
# Currency precedence across the app is: the group's currency when there is a
# group, otherwise the owner's currency.
class AllowPersonalExpenses < ActiveRecord::Migration[8.0]
  def change
    change_column_null :expenses, :group_id, true
    add_reference :expenses, :owner, foreign_key: { to_table: :users }

    add_index :expenses, %i[owner_id spent_on]
    add_check_constraint :expenses, "group_id IS NOT NULL OR owner_id IS NOT NULL",
                         name: "expenses_have_a_home"
  end
end
