# frozen_string_literal: true

class UserPresenter
  TONES = ApplicationHelper::AVATAR_TONES

  def self.collection(users) = users.map { |user| new(user).as_json }

  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: @user.id,
      name: @user.name,
      initials: @user.initials,
      tone: TONES[@user.id % TONES.length],
      avatar: @user.avatar_url(size: 80)
    }
  end
end
