# Each person has their own primary currency, used to present cross-group
# totals from their perspective. It is display preference only - it never
# changes what a group's records are denominated in.
class AddPreferredCurrencyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :preferred_currency_code, :string, limit: 3, null: false, default: "PHP"
    add_foreign_key :users, :currencies, column: :preferred_currency_code, primary_key: :code
    add_index :users, :preferred_currency_code
  end
end
