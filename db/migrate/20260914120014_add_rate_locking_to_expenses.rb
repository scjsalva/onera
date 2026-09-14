# Conversion happens twice, on purpose:
#
#   1. At entry time, so the form can show "about this much in the group's
#      currency". Indicative only - it is a guide, not the number the money
#      follows, and it is recalculated whenever the expense is edited.
#   2. At settle-up, when every unlocked foreign expense in the group is
#      converted at the rate chosen then. That rate is stamped onto the
#      record and is the one balances and settlements are built from.
#
# Once locked, a rate is never recalculated - the historical record is frozen.
class AddRateLockingToExpenses < ActiveRecord::Migration[8.0]
  def change
    add_column :expenses, :rate_locked_at, :datetime
    add_column :expenses, :rate_source, :string, null: false, default: "indicative"
    add_reference :expenses, :rate_locked_by, foreign_key: { to_table: :users }

    add_index :expenses, %i[group_id rate_locked_at]
    add_check_constraint :expenses, "rate_source IN ('indicative','locked','native')",
                         name: "expenses_rate_source_valid"

    reversible do |dir|
      dir.up do
        # Same-currency expenses need no conversion and are locked by definition.
        execute <<~SQL.squish
          UPDATE expenses
             SET rate_source = 'native', rate_locked_at = created_at
           WHERE currency_code = base_currency_code
        SQL
      end
    end
  end
end
