source "https://rubygems.org"

ruby "3.4.2"

gem "rails", "~> 8.0.5"
gem "pg", "~> 1.5"
# json 3.x removed JSON::State#quirks_mode, which Rails 8.0 still calls.
gem "json", "~> 2.9"
gem "puma", ">= 5.0"

# Views
gem "haml-rails"
gem "vite_rails"


# Performance / boot
gem "bootsnap", require: false
gem "propshaft"

group :development do
  gem "web-console"
  gem "listen"
end

group :development, :test do
  gem "debug", platforms: %i[mri], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end
