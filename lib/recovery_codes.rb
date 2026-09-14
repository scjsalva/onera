# frozen_string_literal: true

# Console helpers for when someone loses their recovery codes and can't get in.
#
#   RecoveryCodes.list("john@onera.test")    # what they have, and what's spent
#   RecoveryCodes.reset!("john@onera.test")  # issue a fresh set and print it
#
# reset! prints plaintext because that is the whole point - you read them out
# to the person who is locked out. Nothing readable is kept afterwards.
module RecoveryCodes
  module_function

  def find(identifier)
    user = User.find_by("lower(email) = ?", identifier.to_s.strip.downcase)
    user ||= User.where("lower(name) = ?", identifier.to_s.strip.downcase).first
    raise ActiveRecord::RecordNotFound, "No user matching #{identifier.inspect}" if user.nil?

    user
  end

  def list(identifier)
    user = find(identifier)
    codes = user.recovery_codes.ordered

    puts "#{user.name} <#{user.email}>#{user.archived? ? ' (closed account)' : ''}"
    if codes.empty?
      puts "  no codes issued - run RecoveryCodes.reset!(#{identifier.inspect})"
      return user
    end

    puts "  issued #{user.recovery_codes_generated_at&.to_fs(:short) || 'unknown'}"
    codes.each do |code|
      state = code.used? ? "used #{code.used_at.to_fs(:short)}" : "unused"
      puts format("  %-8s %s", code.label, state)
    end
    puts "  #{user.unused_recovery_codes} of #{codes.size} still usable"
    user
  end

  def reset!(identifier)
    user = find(identifier)
    result = RecoveryCodeIssuer.call(user:)

    puts "New recovery codes for #{user.name} <#{user.email}>:"
    result.codes.each_with_index { |code, index| puts format("  %2d. %s", index + 1, code) }
    puts "Give these to them now - they are not stored in readable form."
    result.codes
  end

  # Last resort when someone has neither their password nor a code.
  def set_password!(identifier, password)
    user = find(identifier)
    user.update!(password:, password_confirmation: password)
    puts "Password set for #{user.name} <#{user.email}>."
    true
  end
end
