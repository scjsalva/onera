# A debt between two friends with no group still has to be settleable, so a
# settlement no longer requires a group either.
class AllowDirectSettlements < ActiveRecord::Migration[8.0]
  def change
    change_column_null :settlements, :group_id, true
    add_index :settlements, %i[payer_id recipient_id settled_on], name: "index_settlements_on_pair_and_date"
  end
end
