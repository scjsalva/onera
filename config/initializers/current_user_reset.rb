# frozen_string_literal: true

# Devise's helpers are the source of truth for the request; Current.user is how
# the rest of the app asks. Reset between requests so a value can never leak
# from one to the next on a reused thread.
Rails.application.config.to_prepare do
  ActiveSupport::Reloader.to_run { Current.reset }
end
