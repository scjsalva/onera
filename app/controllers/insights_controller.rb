# frozen_string_literal: true

class InsightsController < ApplicationController
  def show
    @filter = expense_filter
    @dashboard = DashboardCalculator.new(current_user)
    @by_group = @dashboard.spend_by_group
    @by_category = @dashboard.spend_by_category(filter: @filter)
    @by_month = @dashboard.spend_by_month(months: 6)
  end
end
