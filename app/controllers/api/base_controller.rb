# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    private

    def money_json(money)
      { minor: money.minor, formatted: money.format, currency: money.currency.code }
    end
  end
end
