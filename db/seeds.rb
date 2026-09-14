# frozen_string_literal: true

require_relative "seeds/reference_data"

# Reference data is required for the app to function at all, so it always
# loads and is safe to re-run on every deploy.
Seeds::ReferenceData.load!
puts "Reference data: #{Currency.count} currencies, #{Category.count} categories, #{ExchangeRate.count} rates"

# Demo data is opt-in. db:prepare runs seeds automatically the first time it
# creates a database, so defaulting this on would drop sample groups into a
# production deploy.
load_demo = ENV["SEED_DEMO_DATA"].present? || (Rails.env.development? && ENV["SKIP_DEMO_DATA"].blank?)

if load_demo
  require_relative "seeds/demo_data"
  Seeds::DemoData.load!
else
  puts "Demo data skipped (set SEED_DEMO_DATA=1 to load it)"
end
