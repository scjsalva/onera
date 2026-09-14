# frozen_string_literal: true

require_relative "seeds/reference_data"

# Reference data is required for the app to function at all, so it always
# loads and is safe to re-run on every deploy.
Seeds::ReferenceData.load!
puts "Reference data: #{Currency.count} currencies, #{Category.count} categories, #{ExchangeRate.count} rates"

# Accounts, in development and test only.
#
# The starting password is written in this repository, so seeding these onto a
# deployed app would hand anyone who can read it a working login - and a repo
# being private today is not a reason to depend on it staying private. In
# production the first account is made by hand:
#
#   bin/rails onera:owner ONERA_NAME="Your Name" ONERA_USERNAME=yourname
#
if Rails.env.local?
  require_relative "seeds/people"
  Seeds::People.load!
else
  puts "Accounts not seeded in #{Rails.env} - run: bin/rails onera:owner ONERA_NAME=... ONERA_USERNAME=..."
end

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
