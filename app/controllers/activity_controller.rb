# frozen_string_literal: true

class ActivityController < ApplicationController
  def index
    @events = ActivityEvent.for_groups(current_user.groups.select(:id))
                           .or(ActivityEvent.where(group_id: nil, actor_id: current_user.id))
                           .recent_first.limit(120).includes(:actor, :group)
  end
end
