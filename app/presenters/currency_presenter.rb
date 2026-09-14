# frozen_string_literal: true

# The shape currencies are handed to Vue in. Vue needs the exponent and symbol
# to render a preview; it never needs the rest of the row.
class CurrencyPresenter
  def self.collection(currencies = Currency.active.ordered)
    currencies.map { |currency| new(currency).as_json }
  end

  def initialize(currency)
    @currency = currency
  end

  def as_json(*)
    { code: @currency.code, name: @currency.name, symbol: @currency.symbol, exponent: @currency.exponent }
  end
end
