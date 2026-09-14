# frozen_string_literal: true

# The cross-group view of who owes the current user and who they owe.
# Presentation only: group ledgers are never merged or rewritten.
class BalancesController < ApplicationController
  def index
    @dashboard = DashboardCalculator.new(current_user)
    @counterparties = @dashboard.counterparties
    @summaries = @dashboard.group_summaries
  end
end
