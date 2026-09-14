# frozen_string_literal: true

require "test_helper"

# Installing to a home screen only works if every page carries the manifest and
# the icons. It lived in the signed-in layout alone, so the sign-in page - the
# only page somebody who has not joined yet ever sees - was not installable.
class PwaTest < ActionDispatch::IntegrationTest
  test "the sign-in page is installable" do
    get new_user_session_path

    assert_response :success
    assert_installable response.body
  end

  test "so is a signed-in page" do
    user = create_user(name: "John", username: "pwajohn", email: "pwa@example.com")
    sign_in_as(user)

    get root_path
    assert_response :success
    assert_installable response.body
  end

  # Fetched over HTTP rather than read off disk: these are served by the app
  # now, so the route, the content type and the cache headers are part of what
  # has to be right.
  test "the manifest is served with what a browser needs" do
    get "/manifest.json"

    assert_response :success
    assert_equal "application/manifest+json", response.media_type

    manifest = JSON.parse(response.body)
    assert_equal "standalone", manifest["display"]
    assert_equal "/", manifest["start_url"]
    assert manifest["name"].present?
    assert manifest["short_name"].present?

    sizes = manifest["icons"].map { |icon| icon["sizes"] }
    # Chrome wants both, and refuses to offer an install without them.
    assert_includes sizes, "192x192"
    assert_includes sizes, "512x512"
    assert manifest["icons"].any? { |icon| icon["purpose"].to_s.include?("maskable") }

    manifest["icons"].each do |icon|
      assert Rails.root.join("public#{icon['src']}").exist?,
             "#{icon['src']} is in the manifest but not on disk"
    end
  end

  # Chrome will not offer to install a site whose service worker has no fetch
  # handler, which is why a laptop got a prompt and a phone never did.
  test "the service worker is served, and handles fetch" do
    get "/service-worker.js"

    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_match(/addEventListener\(['"]fetch['"]/, response.body)
    assert_match(/addEventListener\(['"]install['"]/, response.body)
    assert_match(/addEventListener\(['"]activate['"]/, response.body)
  end

  # A worker cached for a year cannot be replaced. Browsers cap that at a day
  # for the script itself, but a day is still a day.
  test "the service worker is not cached for a year the way public files are" do
    get "/service-worker.js"

    cache = response.headers["Cache-Control"].to_s
    refute_match(/max-age=\d{5,}/, cache, "the worker must not be far-future cached")
    assert_match(/no-cache|max-age=0|must-revalidate/, cache)
  end

  # A cached page would mean somebody reading yesterday's balance, which is
  # worse than being told you are offline.
  test "the service worker caches nothing but immutable assets" do
    get "/service-worker.js"

    assert_match %r{\\/vite\\/assets\\/}, response.body, "it should only match Vite's hashed files"
    assert_match(/request\.method !== ['"]GET['"]/, response.body, "writes must never be cached")
  end

  test "both are reachable without signing in" do
    [ "/manifest.json", "/service-worker.js" ].each do |path|
      get path
      assert_response :success, "#{path} should not need a session"
    end
  end

  private

  # Attribute order is HAML's business, not ours - it emits them alphabetically.
  def assert_installable(body)
    assert_match %r{<link[^>]*href="/manifest.json"[^>]*rel="manifest"}, body
    assert_match %r{rel="apple-touch-icon"}, body
    assert_match %r{content="yes"[^>]*name="apple-mobile-web-app-capable"}, body
    assert_match %r{name="apple-mobile-web-app-title"}, body
  end

  def sign_in_as(user)
    get "/sign-in"
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    post "/sign-in", params: { authenticity_token: token,
                               user: { login: user.username, password: "password" } }
    get "/"
  end
end
