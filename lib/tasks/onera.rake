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
end
