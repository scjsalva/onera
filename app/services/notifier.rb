# frozen_string_literal: true

# Creates the notifications for a domain event.
#
# Everything here is in-app only. Email and SMS would each need a paid service
# and a verified sender, so the delivery seam is deliberately narrow: add a
# channel in #deliver and every existing caller picks it up.
class Notifier
  def self.deliver(user:, kind:, title:, body: nil, url: nil, actor: nil, group: nil, subject: nil, metadata: {})
    # Nobody needs telling about their own action, and a closed account has
    # nowhere to read them.
    return if user.nil? || user == actor || user.archived?

    Notification.create!(user:, actor:, group:, subject:, kind:, title:, body:, url:, metadata: metadata.compact)
  end

  # An expense that touches someone's balance: they paid part of it, or they
  # are sharing it. People merely in the group are not told.
  def self.expense_created(expense, actor:)
    return if expense.personal?

    affected(expense).each do |user|
      share = expense.share_for(user.id)
      Notifier.deliver(
        user:, actor:, group: expense.group, subject: expense,
        kind: "expense.added",
        title: "#{actor&.name || 'Someone'} added #{expense.description}",
        body: summary_for(expense, user, share),
        url: Rails.application.routes.url_helpers.expense_path(expense),
        metadata: { amount_minor: expense.amount_minor, currency: expense.currency_code }
      )
    end
  end

  def self.expense_updated(expense, actor:)
    return if expense.personal?

    affected(expense).each do |user|
      Notifier.deliver(
        user:, actor:, group: expense.group, subject: expense,
        kind: "expense.edited",
        title: "#{actor&.name || 'Someone'} edited #{expense.description}",
        body: summary_for(expense, user, expense.share_for(user.id)),
        url: Rails.application.routes.url_helpers.expense_path(expense)
      )
    end
  end

  def self.expense_voided(expense, actor:)
    return if expense.personal?

    affected(expense).each do |user|
      Notifier.deliver(
        user:, actor:, group: expense.group, subject: expense,
        kind: "expense.voided",
        title: "#{actor&.name || 'Someone'} voided #{expense.description}",
        body: "It no longer counts towards anyone's balance.",
        url: Rails.application.routes.url_helpers.expense_path(expense)
      )
    end
  end

  # The person who received the money hears about it; the payer already knows.
  def self.settlement_created(settlement, actor:)
    routes = Rails.application.routes.url_helpers
    # A settlement between two friends has no group, so it has no group page
    # to link to either.
    url = settlement.group ? routes.group_settlements_path(settlement.group) : routes.balances_path
    where = settlement.group ? "In #{settlement.group.name}." : "Just between the two of you."

    Notifier.deliver(
      user: settlement.recipient, actor:, group: settlement.group, subject: settlement,
      kind: "settlement.received",
      title: "#{settlement.payer.name} paid you #{settlement.amount.format}",
      body: settlement.note.presence || where,
      url:
    )

    # If someone recorded a payment on the payer's behalf, tell the payer too.
    return if actor.nil? || actor == settlement.payer

    Notifier.deliver(
      user: settlement.payer, actor:, group: settlement.group, subject: settlement,
      kind: "settlement.recorded",
      title: "#{actor.name} recorded your #{settlement.amount.format} payment",
      body: "To #{settlement.recipient.name}. #{where}",
      url:
    )
  end

  def self.added_to_group(user, group:, actor:)
    Notifier.deliver(
      user:, actor:, group:, subject: group,
      kind: "group.added",
      title: "#{actor&.name || 'Someone'} added you to #{group.name}",
      body: "#{group.users.size} #{'person'.pluralize(group.users.size)} · #{group.base_currency_code}",
      url: Rails.application.routes.url_helpers.group_path(group)
    )
  end

  def self.removed_from_group(user, group:, actor:)
    Notifier.deliver(
      user:, actor:, group: nil, subject: nil,
      kind: "group.removed",
      title: "#{actor&.name || 'Someone'} removed you from #{group.name}",
      body: "You can no longer see that group."
    )
  end

  # Locking rates changes what everyone in the group owes, so everyone hears.
  def self.rates_locked(group, actor:, currencies:, target:)
    group.users.each do |user|
      Notifier.deliver(
        user:, actor:, group:, subject: group,
        kind: "rates.locked",
        title: "#{currencies.to_sentence} locked to #{target} in #{group.name}",
        body: "Balances in this group are now settled in one currency.",
        url: Rails.application.routes.url_helpers.balances_for_group_path(group)
      )
    end
  end

  def self.affected(expense)
    ids = (expense.expense_payers.map(&:user_id) + expense.expense_splits.map(&:user_id)).uniq
    User.where(id: ids).to_a
  end

  def self.summary_for(expense, user, share)
    net = expense.net_for(user.id)
    if net.positive?
      "You're owed #{net.format} of #{expense.amount.format}."
    elsif net.negative?
      "Your share is #{share.format} of #{expense.amount.format}."
    else
      "You're square on this one."
    end
  end

  private_class_method :summary_for
end
