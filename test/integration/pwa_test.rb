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

  test "the manifest itself is served and says what a browser needs" do
    manifest = JSON.parse(Rails.root.join("public/manifest.json").read)

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
      path = Rails.root.join("public#{icon['src']}")
      assert path.exist?, "#{icon['src']} is in the manifest but not on disk"
    end
  end

  # Chrome will not offer to install a site whose service worker has no fetch
  # handler, which is why a laptop got a prompt and a phone never did.
  test "the service worker exists and handles fetch" do
    worker = Rails.root.join("public/service-worker.js")

    assert worker.exist?
    source = worker.read
    assert_match(/addEventListener\(['"]fetch['"]/, source)
    assert_match(/addEventListener\(['"]install['"]/, source)
    assert_match(/addEventListener\(['"]activate['"]/, source)
  end

  # A cached page would mean somebody reading yesterday's balance, which is
  # worse than being told you are offline.
  test "the service worker caches nothing but immutable assets" do
    source = Rails.root.join("public/service-worker.js").read

    # Escaped, because in the worker this is a regex literal.
    assert_match %r{\\/vite\\/assets\\/}, source, "it should only match Vite's hashed files"
    assert_match(/request\.method !== ['"]GET['"]/, source, "writes must never be cached")
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
