# frozen_string_literal: true

class SessionsController < Devise::SessionsController
  layout "plain"

  def create
    super do |user|
      user.update_column(:last_sign_in_at, Time.current) if user.persisted?
    end
  end
end
