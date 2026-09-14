# frozen_string_literal: true

# The single shape a person takes when handed to Vue. Every avatar in the app
# comes through here, so none of them can quietly miss a field.
class UserPresenter
  def self.collection(users) = users.map { |user| new(user).as_json }

  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: @user.id,
      name: @user.name,
      initials: @user.initials,
      tone: @user.tone_class,
      toneText: @user.tone_text_class,
      avatar: @user.avatar_url(size: 80)
    }
  end
end
