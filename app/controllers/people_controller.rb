# frozen_string_literal: true

# The directory of everyone in Onera. Accounts are not created here any more -
# people join themselves through an invite link.
class PeopleController < ApplicationController
  def index
    @people = User.active.ordered.includes(:groups)
    @invitation = Invitation.for(group: nil, creator: current_user)
  end
end
