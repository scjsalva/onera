# frozen_string_literal: true

# Adding and removing the people you can see. Not a social graph - just the
# answer to "may these two put each other on an expense outside a group?".
class FriendshipsController < ApplicationController
  def create
    other = find_person(params[:login])

    if other.nil?
      return redirect_to people_path,
                         alert: "No account matches that username or email. Check it, or send them an invite link."
    end

    if other == current_user
      return redirect_to people_path, alert: "That's you."
    end

    friendship = Friendship.request(from: current_user, to: other)

    if friendship.persisted?
      notify(friendship, other)
      redirect_to people_path, notice: message_for(friendship, other)
    else
      redirect_to people_path, alert: friendship.errors.full_messages.to_sentence
    end
  end

  def accept
    friendship = current_user.received_friend_requests.pending.find(params[:id])
    friendship.accept!

    Notifier.deliver(
      user: friendship.requester, actor: current_user, kind: "friend.accepted",
      title: "#{current_user.name} accepted your request",
      body: "You can now split expenses directly.",
      url: people_path
    )

    redirect_to people_path, notice: "You and #{friendship.requester.name} are connected."
  end

  # Covers all three ways a connection ends: declining, cancelling, unfriending.
  def destroy
    friendship = Friendship.involving(current_user).find(params[:id])
    other = friendship.other_than(current_user)
    was_accepted = friendship.accepted?
    friendship.destroy!

    redirect_to people_path,
                notice: was_accepted ? "Removed #{other.name}." : "Request withdrawn."
  end

  private

  # Found by either identifier, the same two a person signs in with.
  def find_person(login)
    value = login.to_s.strip.downcase
    return nil if value.blank?

    User.active.where("lower(username) = :v OR lower(email) = :v", v: value).first
  end

  def notify(friendship, other)
    if friendship.accepted?
      Notifier.deliver(user: other, actor: current_user, kind: "friend.accepted",
                       title: "#{current_user.name} added you back",
                       body: "You can now split expenses directly.", url: people_path)
    else
      Notifier.deliver(user: other, actor: current_user, kind: "friend.requested",
                       title: "#{current_user.name} wants to connect",
                       body: "Accept to split expenses directly.", url: people_path)
    end
  end

  def message_for(friendship, other)
    return "You and #{other.name} are connected." if friendship.accepted?
    return "Request sent to #{other.name}." if friendship.requester == current_user

    "#{other.name} already asked you - accept it below."
  end
end
