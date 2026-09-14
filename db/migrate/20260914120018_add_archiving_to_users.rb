# Deleting a person anonymizes rather than destroys them.
#
# Their rows are referenced by expenses, payers, splits and settlements, so
# removing the record would either orphan financial history or cascade a
# delete through it. Instead the identifying fields are cleared and the user
# is archived: hidden from every place you pick a person, still resolvable
# everywhere their money appears.
#
# archived_ordinal gives each anonymized person a stable number so two of them
# are never indistinguishable in a list.
class AddArchivingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :archived_at, :datetime
    add_column :users, :archived_ordinal, :integer

    add_index :users, :archived_at
    add_index :users, :archived_ordinal, unique: true, where: "archived_ordinal IS NOT NULL"
  end
end
