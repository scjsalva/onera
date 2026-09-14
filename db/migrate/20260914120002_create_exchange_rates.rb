class CreateExchangeRates < ActiveRecord::Migration[8.0]
  def change
    create_table :exchange_rates do |t|
      t.string :base_currency_code, limit: 3, null: false
      t.string :quote_currency_code, limit: 3, null: false
      # 1 base_currency == rate quote_currency
      t.decimal :rate, precision: 24, scale: 12, null: false
      t.date :rate_date, null: false
      t.string :source, null: false, default: "manual"
      t.timestamps
    end

    add_foreign_key :exchange_rates, :currencies, column: :base_currency_code, primary_key: :code
    add_foreign_key :exchange_rates, :currencies, column: :quote_currency_code, primary_key: :code
    add_index :exchange_rates, %i[base_currency_code quote_currency_code rate_date],
              unique: true, name: "index_exchange_rates_on_pair_and_date"
    add_check_constraint :exchange_rates, "rate > 0", name: "exchange_rates_positive"
  end
end
