# frozen_string_literal: true

namespace :onera do
  desc "Create the first account on a fresh deployment (ONERA_NAME=, ONERA_USERNAME=, optional ONERA_EMAIL=)"
  task owner: :environment do
    name = ENV["ONERA_NAME"].presence
    username = ENV["ONERA_USERNAME"].presence

    abort "ONERA_NAME and ONERA_USERNAME are required, e.g. bin/rails onera:owner ONERA_NAME='Jane' ONERA_USERNAME=jane" if name.nil? || username.nil?

    if User.where("lower(username) = ?", username.downcase).exists?
      abort "#{username} already exists. Use onera:password to set a new password instead."
    end

    # Generated rather than chosen, so a real password never has to travel
    # through a shell history or a chat message on the way here.
    password = SecureRandom.alphanumeric(16)

    user = User.create!(name:, username:, email: ENV["ONERA_EMAIL"].presence,
                        password:, password_confirmation: password)
    codes = RecoveryCodeIssuer.call(user:).codes

    puts "\nAccount created."
    puts "  username: #{user.username}"
    puts "  password: #{password}"
    puts "\nRecovery codes - save these, they are not shown again:"
    codes.each_with_index { |code, index| puts format("  %2d. %s", index + 1, code) }
    puts "\nSign in, change the password, then invite everyone else from You -> People."
  end

  desc "Set a new password for someone locked out (ONERA_USERNAME=)"
  task password: :environment do
    username = ENV["ONERA_USERNAME"].presence
    abort "ONERA_USERNAME is required" if username.nil?

    user = User.find_by("lower(username) = ?", username.downcase)
    abort "No account called #{username}" if user.nil?

    password = SecureRandom.alphanumeric(16)
    user.update!(password:, password_confirmation: password)

    puts "New password for #{user.username}: #{password}"
  end

  desc "Show how many recovery codes someone has left (ONERA_USERNAME=)"
  task codes: :environment do
    username = ENV["ONERA_USERNAME"].presence
    abort "ONERA_USERNAME is required" if username.nil?

    RecoveryCodes.list(username)
  end

  desc "Print a signup link for a deployment with nobody in it yet " \
       "(optional ONERA_URL=, ONERA_INVITE_USES=, ONERA_INVITE_DAYS=)"
  task invite: :environment do
    # No creator: on a fresh deployment there is nobody to have sent it. This
    # is how the first person gets an account without a shell on the server.
    #
    # It is capped and dated by default. While this link is live it also puts a
    # Create an account button on the sign-in page, and the app is on a public
    # address - so it should stop on its own even if nobody remembers to revoke
    # it. Pass 0 for either to mean no limit.
    uses = Integer(ENV.fetch("ONERA_INVITE_USES", 10))
    days = Integer(ENV.fetch("ONERA_INVITE_DAYS", 7))

    invitation = Invitation.live.find_by(created_by: nil, group: nil) ||
                 Invitation.create!(created_by: nil, group: nil,
                                    max_uses: uses.positive? ? uses : nil,
                                    expires_at: days.positive? ? days.days.from_now : nil)

    base = ENV["ONERA_URL"].presence ||
           (ENV["APP_HOST"].presence && "https://#{ENV['APP_HOST']}") ||
           "http://localhost:3000"

    puts invitation.share_url(base)
    puts
    limits = []
    limits << "#{invitation.uses_left} of #{invitation.max_uses} uses left" if invitation.max_uses
    limits << "expires #{invitation.expires_at.to_fs(:long)}" if invitation.expires_at
    puts limits.any? ? limits.join(", ") : "No limit on uses and no expiry."
    puts
    puts "While it is live the sign-in page offers Create an account. Close it early with:"
    puts "  bin/rails onera:revoke_invites"
  end

  desc "Revoke every signup link that has no sender"
  task revoke_invites: :environment do
    count = Invitation.live.where(created_by: nil).update_all(revoked_at: Time.current)
    puts "Revoked #{count} #{'link'.pluralize(count)}."
  end
end
