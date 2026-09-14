# frozen_string_literal: true

# The people you can see: the ones you have added. Everyone else in Onera is
# invisible here on purpose - a shared group lets you split with someone, but
# it does not put them in your address book.
class PeopleController < ApplicationController
  def index
    @friends = current_user.friends.ordered
    @incoming = current_user.incoming_friend_requests
    @outgoing = current_user.outgoing_friend_requests
    @invitation = Invitation.for(group: nil, creator: current_user)
    @ledger = DirectLedger.new(current_user)
  end
end
