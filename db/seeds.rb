# frozen_string_literal: true

require_relative "seeds/reference_data"

Seeds::ReferenceData.load!
puts "Reference data: #{Currency.count} currencies, #{Category.count} categories, #{ExchangeRate.count} rates"

if ENV["SKIP_DEMO_DATA"].blank?
  require_relative "seeds/demo_data"
  Seeds::DemoData.load!
end
