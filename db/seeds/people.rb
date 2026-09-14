# frozen_string_literal: true

# The starting set of accounts. Everyone gets the same known password so the
# app is usable the moment it boots; the profile nags them to change it.
module Seeds
  module People
    DEFAULT_PASSWORD = "password"

    # Email is deliberately absent: it is optional, and leaving it out means
    # the first-sign-in email prompt is exercised by the seeded accounts too.
    PEOPLE = [
      { name: "John Carlo Salva",  username: "scjsalva" },
      { name: "Christian Nasayao", username: "cnasayao" },
      { name: "Lydia Valencia",    username: "ljvalencia" },
      { name: "Kristayn Flores",   username: "kaflores" },
      { name: "Eilon Blanche",     username: "egblance" },
      { name: "Andrew Egonia",     username: "aegonia" }
    ].freeze

    # Everyone starts connected to the first account and to nobody else, so
    # the visibility rules are visible from the first minute: that person can
    # tag anyone directly, and the rest can only reach each other by sharing a
    # group.
    def self.connect_to_first!
      hub = User.find_by(username: PEOPLE.first[:username])
      return if hub.nil?

      PEOPLE.drop(1).each do |attrs|
        other = User.find_by(username: attrs[:username])
        next if other.nil? || Friendship.between(hub, other)

        Friendship.create!(requester: hub, addressee: other, status: "accepted",
                           responded_at: Time.current)
      end

      puts "Friendships: #{hub.username} is connected to #{hub.friends.count} people, who are not " \
           "connected to each other"
    end

    def self.load!
      PEOPLE.each do |attrs|
        user = User.find_or_initialize_by(username: attrs[:username])
        user.name = attrs[:name]
        user.preferred_currency_code ||= "PHP"
        user.password = DEFAULT_PASSWORD if user.new_record?
        user.password_confirmation = user.password if user.new_record?
        user.save!

        RecoveryCodeIssuer.call(user:) unless user.recovery_codes_issued?
      end

      connect_to_first!

      puts "People: #{User.active.count} accounts (#{PEOPLE.map { |p| p[:username] }.join(', ')}), " \
           "password #{DEFAULT_PASSWORD.inspect}"
    end
  end
end
