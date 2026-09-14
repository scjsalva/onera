# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    @filter = expense_filter
    @dashboard = DashboardCalculator.new(current_user)
    @summaries = @dashboard.group_summaries
    @recent_expenses = @dashboard.recent_expenses(filter: @filter)
    @recent_settlements = @dashboard.recent_settlements
    @counterparties = @dashboard.counterparties
    @spend_by_category = @dashboard.spend_by_category(filter: @filter).first(6)
    @spend_by_month = @dashboard.spend_by_month
  end
end
