# frozen_string_literal: true

class NotificationPresenter
  def initialize(notification)
    @n = notification
  end

  def as_json(*)
    {
      id: @n.id,
      kind: @n.kind,
      icon: @n.icon,
      title: @n.title,
      body: @n.body,
      url: @n.url,
      group: @n.group&.name,
      read: @n.read?,
      actor: @n.actor && UserPresenter.new(@n.actor).as_json,
      at: @n.created_at.iso8601,
      ago: ActionController::Base.helpers.time_ago_in_words(@n.created_at)
    }
  end
end
