# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Reference data is not fixtures: currencies and categories are rows the
    # application cannot function without, so every test gets them.
    setup do
      unless Currency.exists?
        require Rails.root.join("db/seeds/reference_data")
        Seeds::ReferenceData.load!
      end
    end

    def php = Currency.find("PHP")
    def jpy = Currency.find("JPY")
    def usd = Currency.find("USD")

    def create_user(name:, username: nil, **attrs)
      User.create!(
        name:,
        username: username || name.downcase.gsub(/[^a-z]/, "")[0, 20],
        password: "password",
        password_confirmation: "password",
        **attrs
      )
    end

    def create_group(name: "Trip", currency: "PHP", members: [], creator: nil)
      group = Group.create!(name:, base_currency_code: currency, created_by: creator || members.first)
      members.each { |m| GroupMembership.create!(group:, user: m) }
      group
    end

    # Builds an expense through the real service, so tests exercise the same
    # validation and rounding the application does.
    def add_expense(group:, actor:, payers:, participants:, **params)
      result = ExpenseCreator.call(
        group:, actor:,
        params: {
          description: "Expense", currency_code: group.base_currency_code,
          spent_on: Date.current, split_method: "equal",
          payers:, participants:, **params
        }
      )
      raise "expense failed: #{result.errors.join(', ')}" unless result.success?

      result.expense
    end
  end
end
