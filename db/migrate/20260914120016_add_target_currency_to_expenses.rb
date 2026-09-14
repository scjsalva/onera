# A rate lock converts into a chosen currency, which defaults to the group's
# primary currency but can be overridden at settle-up. Recording the target
# alongside the rate keeps the locked figure self-describing.
class AddTargetCurrencyToExpenses < ActiveRecord::Migration[8.0]
  def change
    add_column :settlements, :settles_currency_code, :string, limit: 3
    add_foreign_key :settlements, :currencies, column: :settles_currency_code, primary_key: :code
    add_index :settlements, :settles_currency_code
  end
end
