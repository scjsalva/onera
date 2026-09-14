# frozen_string_literal: true

# Reference data the application cannot run without. Idempotent, so it is safe
# to re-run on every deploy.
module Seeds
  module ReferenceData
    CURRENCIES = [
      { code: "PHP", name: "Philippine Peso",    symbol: "₱",   exponent: 2, position: 1 },
      { code: "USD", name: "US Dollar",          symbol: "$",   exponent: 2, position: 2 },
      { code: "SGD", name: "Singapore Dollar",   symbol: "S$",  exponent: 2, position: 3 },
      { code: "JPY", name: "Japanese Yen",       symbol: "¥",   exponent: 0, position: 4 },
      { code: "THB", name: "Thai Baht",          symbol: "฿",   exponent: 2, position: 5 },
      { code: "IDR", name: "Indonesian Rupiah",  symbol: "Rp",  exponent: 2, position: 6 },
      { code: "CNY", name: "Chinese Yuan",       symbol: "CN¥", exponent: 2, position: 7 },
      { code: "HKD", name: "Hong Kong Dollar",   symbol: "HK$", exponent: 2, position: 8 },
      { code: "GBP", name: "British Pound",      symbol: "£",   exponent: 2, position: 9 },
      { code: "EUR", name: "Euro",               symbol: "€",   exponent: 2, position: 10 },
      { code: "KRW", name: "South Korean Won",   symbol: "₩",   exponent: 0, position: 11 },
      { code: "MYR", name: "Malaysian Ringgit",  symbol: "RM",  exponent: 2, position: 12 },
      { code: "AUD", name: "Australian Dollar",  symbol: "A$",  exponent: 2, position: 13 },
      { code: "CAD", name: "Canadian Dollar",    symbol: "C$",  exponent: 2, position: 14 }
    ].freeze

    # 1 unit of the key is worth this many PHP. Indicative reference values,
    # editable in the app - there is no live rate feed wired up.
    RATES_TO_PHP = {
      "USD" => "58.20",
      "SGD" => "45.10",
      "JPY" => "0.39",
      "THB" => "1.78",
      "IDR" => "0.0035",
      "CNY" => "8.12",
      "HKD" => "7.44",
      "GBP" => "76.40",
      "EUR" => "64.30",
      "KRW" => "0.043",
      "MYR" => "13.60",
      "AUD" => "38.50",
      "CAD" => "42.10"
    }.freeze

    CATEGORIES = [
      { name: "Food",          slug: "food",          icon: "utensils",  color: "sand",     position: 1 },
      { name: "Drinks",        slug: "drinks",        icon: "cup",       color: "sand",     position: 2 },
      { name: "Groceries",     slug: "groceries",     icon: "basket",    color: "positive", position: 3 },
      { name: "Transport",     slug: "transport",     icon: "train",     color: "brand",    position: 4 },
      { name: "Accommodation", slug: "accommodation", icon: "bed",       color: "brand",    position: 5 },
      { name: "Tickets",       slug: "tickets",       icon: "ticket",    color: "brand",    position: 6 },
      { name: "Entertainment", slug: "entertainment", icon: "sparkles",  color: "brand",    position: 7 },
      { name: "Shopping",      slug: "shopping",      icon: "bag",       color: "sand",     position: 8 },
      { name: "Utilities",     slug: "utilities",     icon: "bolt",      color: "ink",      position: 9 },
      { name: "Health",        slug: "health",        icon: "heart",     color: "negative", position: 10 },
      { name: "Other",         slug: "other",         icon: "receipt",   color: "ink",      position: 99 }
    ].freeze

    def self.load!(rate_date: 1.year.ago.to_date)
      CURRENCIES.each do |attrs|
        Currency.find_or_initialize_by(code: attrs[:code]).update!(attrs.except(:code))
      end

      CATEGORIES.each do |attrs|
        Category.find_or_initialize_by(slug: attrs[:slug]).update!(attrs.except(:slug))
      end

      RATES_TO_PHP.each do |code, rate|
        ExchangeRate.find_or_initialize_by(
          base_currency_code: code, quote_currency_code: "PHP", rate_date:
        ).update!(rate: BigDecimal(rate), source: "reference")
      end
    end
  end
end
