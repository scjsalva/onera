# frozen_string_literal: true

# Renders every GET route as a signed-in person and fails on anything that
# errors. Template syntax mistakes don't surface until a page is rendered, so
# this is the cheapest way to catch them.
require_relative "../config/environment"
require "rack/test"

# Signs in the way a person does, so the crawl exercises the real login path
# on its way to rendering everything else.

class SmokeCrawl
  include Rack::Test::Methods

  def app = Rails.application

  # Rack::Test defaults to example.org, which development's host
  # authorization blocks with a 403 that looks nothing like an auth failure.
  def default_host = "localhost"

  def run
    user = User.active.find_by(email: "john@onera.test") || User.active.first
    abort "no user to sign in as - run bin/rails db:seed" if user.nil?

    sign_in(user)
    failures = []

    paths(user).each do |path|
      begin
        get path
        follow_redirect! while last_response.redirect?
      rescue StandardError => e
        failures << "#{path} raised #{e.class}"
        puts "  FAIL #{path} raised #{e.class}: #{e.message.lines.first.to_s.strip[0, 160]}"
        puts "       #{e.backtrace.grep(%r{/app/}).first}"
        next
      end

      if last_response.ok?
        puts "  ok   #{path}"
      else
        failures << "#{path} -> #{last_response.status}"
        puts "  FAIL #{path} -> #{last_response.status}"
        error = last_request.env["action_dispatch.exception"]
        if error
          puts "       #{error.class}: #{error.message.lines.first.to_s.strip[0, 200]}"
          puts "       #{error.backtrace.grep(%r{/app/}).first}"
        end
      end
    end

    if failures.any?
      puts "\n#{failures.size} route(s) failed"
      exit 1
    end

    puts "\nall #{paths(user).size} routes rendered"
  end

  private

  def sign_in(user)
    # A previous run may have changed the seeded password.
    user.update!(password: "password", password_confirmation: "password")

    get "/sign-in"
    token = last_response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    abort "no CSRF token on the sign-in page" if token.nil?

    post "/sign-in", authenticity_token: token,
                     user: { login: user.username, password: "password" }
    abort "could not sign in (#{last_response.status})" unless last_response.redirect?

    follow_redirect! while last_response.redirect?
    abort "sign-in landed on #{last_response.status}" unless last_response.ok?
  end

  def paths(user)
    @paths ||= begin
      group = user.groups.first
      expense = Expense.where(group: user.groups).or(Expense.where(owner: user)).first

      list = %w[/ /groups /groups/new /expenses /balances /activity /insights
                /people /invitations /profile /profile/edit /notifications
                /password/edit /recovery_codes /email/edit]

      if group
        list += [ "/groups/#{group.id}", "/groups/#{group.id}/edit",
                  "/groups/#{group.id}/expenses", "/groups/#{group.id}/balances",
                  "/groups/#{group.id}/activity", "/groups/#{group.id}/memberships",
                  "/groups/#{group.id}/settlements", "/groups/#{group.id}/settlements/new",
                  "/groups/#{group.id}/settle_up" ]
      end

      list << "/expenses/#{expense.id}" if expense
      list << "/expenses/#{expense.id}/edit" if expense
      list
    end
  end
end

SmokeCrawl.new.run
