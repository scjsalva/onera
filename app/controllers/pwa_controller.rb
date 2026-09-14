# frozen_string_literal: true

# Serves the two files that make the app installable.
#
# They are not in public/ because Rails' static file server stamps everything
# there with a year of cache. A service worker cached for a year cannot be
# replaced - browsers cap that at a day for the worker script itself, but a day
# is still a day, and the manifest has no cap at all.
class PwaController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_user
  # Rails refuses to serve JavaScript cross-origin without this, and a service
  # worker is fetched by the browser rather than by a page. Neither file holds
  # anything belonging to anybody.
  skip_forgery_protection

  def service_worker
    expires_in 0, public: false, must_revalidate: true
    render template: "pwa/service-worker", layout: false, content_type: "text/javascript"
  end

  def manifest
    expires_in 1.hour, public: true
    render template: "pwa/manifest", layout: false, content_type: "application/manifest+json"
  end
end
