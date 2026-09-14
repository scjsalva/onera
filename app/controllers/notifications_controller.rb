# frozen_string_literal: true

class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.recent_first.limit(100).includes(:actor, :group)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          unread: current_user.notifications.unread.count,
          notifications: @notifications.first(20).map { |n| NotificationPresenter.new(n).as_json }
        }
      end
    end
  end

  # Tapping a notification should take you to the thing it is about.
  # redirect_back sent you to the page you were already on, which read as
  # nothing happening at all.
  def update
    notification = current_user.notifications.find(params[:id])
    notification.mark_read!

    if notification.subject_missing?
      return redirect_to notifications_path,
                         notice: "That's been removed since you were told about it."
    end

    redirect_to notification.url.presence || notifications_path
  end

  def read_all
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_back fallback_location: notifications_path, notice: "All caught up."
  end
end
