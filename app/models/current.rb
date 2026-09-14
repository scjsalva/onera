# frozen_string_literal: true

# The single place the application asks "who is looking at this?".
#
# Today it is populated from a session-selected user id. When real
# authentication lands, only ApplicationController#set_current_user changes -
# nothing in the financial domain reads the session directly.
class Current < ActiveSupport::CurrentAttributes
  attribute :user

  def user_id = user&.id
end
