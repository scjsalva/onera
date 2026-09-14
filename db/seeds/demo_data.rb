# frozen_string_literal: true

# Realistic data to explore the application with. Everything is created
# through the real services, so the seeds exercise the same validation,
# rounding and history paths the UI does.
module Seeds
  module DemoData
    module_function

    def load!
      return puts("Demo data already present - skipping") if Group.exists?

      people = create_people
      japan = japan_trip(people)
      singapore = singapore_trip(people)
      apartment(people)
      weekend(people)
      personal_expenses(people)

      settle(japan, people)
      settle_singapore(singapore, people)

      puts "Demo data: #{User.count} people, #{Group.count} groups, " \
           "#{Expense.count} expenses (#{Expense.personal.count} personal), #{Settlement.count} settlements"
    end

    def create_people
      {
        john: find_person("John Salva", "john@example.com", Date.new(1998, 1, 15), "PHP"),
        alice: find_person("Alice Cruz", "alice@example.com", Date.new(1995, 6, 2), "PHP"),
        bob: find_person("Bob Santos", nil, Date.new(1992, 11, 30), "SGD"),
        sarah: find_person("Sarah Reyes", "sarah@example.com", Date.new(1999, 3, 21), "PHP")
      }
    end

    def find_person(name, email, dob, currency)
      User.find_or_create_by!(name:) do |user|
        user.email = email
        user.date_of_birth = dob
        user.preferred_currency_code = currency
      end
    end

    def build_group(name, description, currency, members, creator)
      group = Group.create!(name:, description:, base_currency_code: currency, created_by: creator)
      members.each { |member| GroupMembership.create!(group:, user: member) }
      ActivityRecorder.record(action: "group.created", summary: "#{creator.name} created #{name}",
                              group:, actor: creator, subject: group)
      group
    end

    def add_expense(group:, actor:, **params)
      result = ExpenseCreator.call(group:, actor:, params:)
      raise "Seed expense failed: #{result.errors.join(', ')}" unless result.success?

      result.expense
    end

    def add_personal(owner:, **params)
      result = ExpenseCreator.call(owner:, actor: owner, params:)
      raise "Seed personal expense failed: #{result.errors.join(', ')}" unless result.success?

      result.expense
    end

    def category(slug) = Category.find_by(slug:)

    # A yen-denominated trip run by a peso group: the case the whole
    # currency model exists for.
    def japan_trip(people)
      john, alice, bob, sarah = people.values_at(:john, :alice, :bob, :sarah)
      group = build_group("Japan Trip", "Two weeks in Tokyo, Kyoto and Osaka.", "PHP",
                          [ john, alice, bob, sarah ], john)

      add_expense(
        group:, actor: john, description: "Dinner in Shibuya", currency_code: "JPY",
        amount: "8400", spent_on: 12.days.ago.to_date, category_id: category("food").id,
        split_method: "equal", notes: "Izakaya near the station.",
        payers: [ { user_id: john.id, amount: "8400" } ],
        participants: [ john, alice, bob ].map { |u| { user_id: u.id } }
      )

      add_expense(
        group:, actor: john, description: "Universal Studios tickets", currency_code: "JPY",
        amount: "24000", spent_on: 11.days.ago.to_date, category_id: category("tickets").id,
        split_method: "equal",
        payers: [ { user_id: john.id, amount: "16000" }, { user_id: alice.id, amount: "8000" } ],
        participants: [ john, alice, bob, sarah ].map { |u| { user_id: u.id } }
      )

      # John pays the lot but is not sharing it - a payer need not be a participant.
      add_expense(
        group:, actor: john, description: "Airport transfer for the others", currency_code: "JPY",
        amount: "9000", spent_on: 13.days.ago.to_date, category_id: category("transport").id,
        split_method: "equal",
        payers: [ { user_id: john.id, amount: "9000" } ],
        participants: [ alice, bob, sarah ].map { |u| { user_id: u.id } }
      )

      add_expense(
        group:, actor: alice, description: "Ryokan in Kyoto", currency_code: "JPY",
        amount: "62000", spent_on: 9.days.ago.to_date, category_id: category("accommodation").id,
        split_method: "shares", notes: "Alice and Sarah took the larger room.",
        payers: [ { user_id: alice.id, amount: "62000" } ],
        participants: [
          { user_id: john.id, split_value: "1" }, { user_id: alice.id, split_value: "2" },
          { user_id: bob.id, split_value: "1" }, { user_id: sarah.id, split_value: "2" }
        ]
      )

      add_expense(
        group:, actor: sarah, description: "Shinkansen to Osaka", currency_code: "JPY",
        amount: "13870", spent_on: 8.days.ago.to_date, category_id: category("transport").id,
        split_method: "equal",
        payers: [ { user_id: sarah.id, amount: "13870" } ],
        participants: [ john, alice, bob, sarah ].map { |u| { user_id: u.id } }
      )

      add_expense(
        group:, actor: bob, description: "Duty free on the way home", currency_code: "PHP",
        amount: "4500", spent_on: 6.days.ago.to_date, category_id: category("shopping").id,
        split_method: "percentage",
        payers: [ { user_id: bob.id, amount: "4500" } ],
        participants: [
          { user_id: john.id, split_value: "50" }, { user_id: bob.id, split_value: "30" },
          { user_id: sarah.id, split_value: "20" }
        ]
      )

      edited = add_expense(
        group:, actor: john, description: "Karaoke", currency_code: "JPY",
        amount: "6000", spent_on: 7.days.ago.to_date, category_id: category("entertainment").id,
        split_method: "equal",
        payers: [ { user_id: john.id, amount: "6000" } ],
        participants: [ john, alice, bob ].map { |u| { user_id: u.id } }
      )
      ExpenseUpdater.call(
        expense: edited, actor: john,
        params: {
          description: "Karaoke and late-night ramen", currency_code: "JPY", amount: "7800",
          spent_on: edited.spent_on, category_id: category("entertainment").id, split_method: "equal",
          payers: [ { user_id: john.id, amount: "7800" } ],
          participants: [ john, alice, bob, sarah ].map { |u| { user_id: u.id } }
        }
      )

      voided = add_expense(
        group:, actor: alice, description: "Cancelled tea ceremony booking", currency_code: "JPY",
        amount: "12000", spent_on: 10.days.ago.to_date, category_id: category("entertainment").id,
        split_method: "equal",
        payers: [ { user_id: alice.id, amount: "12000" } ],
        participants: [ john, alice, sarah ].map { |u| { user_id: u.id } }
      )
      ExpenseVoider.call(expense: voided, actor: alice, reason: "Booking refunded in full")

      group
    end

    def singapore_trip(people)
      john, alice, bob = people.values_at(:john, :alice, :bob)
      group = build_group("Singapore Trip", "Long weekend, Bob hosting.", "SGD", [ john, alice, bob ], bob)

      add_expense(
        group:, actor: bob, description: "Hotel on Orchard Road", currency_code: "SGD",
        amount: "960", spent_on: 21.days.ago.to_date, category_id: category("accommodation").id,
        split_method: "equal",
        payers: [ { user_id: bob.id, amount: "960" } ],
        participants: [ john, alice, bob ].map { |u| { user_id: u.id } }
      )

      add_expense(
        group:, actor: john, description: "Gardens by the Bay", currency_code: "SGD",
        amount: "84", spent_on: 20.days.ago.to_date, category_id: category("tickets").id,
        split_method: "equal",
        payers: [ { user_id: john.id, amount: "84" } ],
        participants: [ john, alice, bob ].map { |u| { user_id: u.id } }
      )

      add_expense(
        group:, actor: alice, description: "Hawker centre dinners", currency_code: "SGD",
        amount: "126.50", spent_on: 19.days.ago.to_date, category_id: category("food").id,
        split_method: "fixed",
        payers: [ { user_id: alice.id, amount: "126.50" } ],
        participants: [
          { user_id: john.id, split_value: "42.50" }, { user_id: alice.id, split_value: "44.00" },
          { user_id: bob.id, split_value: "40.00" }
        ]
      )

      add_expense(
        group:, actor: john, description: "Airport lounge day passes", currency_code: "USD",
        amount: "150", spent_on: 18.days.ago.to_date, category_id: category("transport").id,
        split_method: "equal",
        payers: [ { user_id: john.id, amount: "100" }, { user_id: alice.id, amount: "50" } ],
        participants: [ john, alice, bob ].map { |u| { user_id: u.id } }
      )

      group
    end

    def apartment(people)
      john, sarah = people.values_at(:john, :sarah)
      group = build_group("Apartment", "Shared flat running costs.", "PHP", [ john, sarah ], john)

      add_expense(
        group:, actor: john, description: "Electricity", currency_code: "PHP", amount: "3480",
        spent_on: 5.days.ago.to_date, category_id: category("utilities").id, split_method: "equal",
        payers: [ { user_id: john.id, amount: "3480" } ],
        participants: [ john, sarah ].map { |u| { user_id: u.id } }
      )

      add_expense(
        group:, actor: sarah, description: "Weekly groceries", currency_code: "PHP", amount: "2650",
        spent_on: 3.days.ago.to_date, category_id: category("groceries").id, split_method: "equal",
        payers: [ { user_id: sarah.id, amount: "2650" } ],
        participants: [ john, sarah ].map { |u| { user_id: u.id } }
      )

      add_expense(
        group:, actor: john, description: "Internet", currency_code: "PHP", amount: "1999",
        spent_on: 2.days.ago.to_date, category_id: category("utilities").id, split_method: "percentage",
        payers: [ { user_id: john.id, amount: "1999" } ],
        participants: [ { user_id: john.id, split_value: "60" }, { user_id: sarah.id, split_value: "40" } ]
      )

      group
    end

    def weekend(people)
      alice, bob, sarah = people.values_at(:alice, :bob, :sarah)
      group = build_group("Weekend Trip", "Batangas, one night.", "PHP", [ alice, bob, sarah ], alice)

      add_expense(
        group:, actor: alice, description: "Beach house", currency_code: "PHP", amount: "9000",
        spent_on: 30.days.ago.to_date, category_id: category("accommodation").id, split_method: "equal",
        payers: [ { user_id: alice.id, amount: "9000" } ],
        participants: [ alice, bob, sarah ].map { |u| { user_id: u.id } }
      )

      add_expense(
        group:, actor: bob, description: "Petrol and tolls", currency_code: "PHP", amount: "2100",
        spent_on: 30.days.ago.to_date, category_id: category("transport").id, split_method: "equal",
        payers: [ { user_id: bob.id, amount: "2100" } ],
        participants: [ alice, bob, sarah ].map { |u| { user_id: u.id } }
      )

      group
    end

    # Expenses with no group: they count towards the owner's own spending and
    # never create a debt.
    def personal_expenses(people)
      john, alice = people.values_at(:john, :alice)

      add_personal(owner: john, description: "Coffee subscription", currency_code: "PHP",
                   amount: "890", spent_on: 4.days.ago.to_date, category_id: category("drinks").id)
      add_personal(owner: john, description: "New running shoes", currency_code: "PHP",
                   amount: "6450", spent_on: 15.days.ago.to_date, category_id: category("shopping").id)
      add_personal(owner: john, description: "Airport parking", currency_code: "PHP",
                   amount: "1250", spent_on: 14.days.ago.to_date, category_id: category("transport").id)
      add_personal(owner: alice, description: "Gym membership", currency_code: "PHP",
                   amount: "2200", spent_on: 8.days.ago.to_date, category_id: category("health").id)
    end

    def settle(group, people)
      john, alice, bob, sarah = people.values_at(:john, :alice, :bob, :sarah)

      # Settled in the currency the debt was actually incurred in.
      SettlementCreator.call(
        group:, actor: john,
        params: { payer_id: john.id, recipient_id: bob.id, currency_code: "PHP",
                  amount: "2250", settled_on: 4.days.ago.to_date, payment_method: "GCash",
                  note: "Squared up the duty-free run." }
      )

      # Partial: Sarah owes more yen than this, so a balance remains.
      SettlementCreator.call(
        group:, actor: sarah,
        params: { payer_id: sarah.id, recipient_id: alice.id, currency_code: "JPY",
                  amount: "9000", settled_on: 2.days.ago.to_date, payment_method: "Cash",
                  note: "Part of the ryokan money." }
      )

      SettlementCreator.call(
        group:, actor: bob,
        params: { payer_id: bob.id, recipient_id: john.id, currency_code: "JPY",
                  amount: "5000", settled_on: 1.day.ago.to_date, payment_method: "Cash" }
      )
    end

    def settle_singapore(group, people)
      john, bob = people.values_at(:john, :bob)

      SettlementCreator.call(
        group:, actor: john,
        params: { payer_id: john.id, recipient_id: bob.id, currency_code: "SGD",
                  amount: "150", settled_on: 12.days.ago.to_date, payment_method: "Bank transfer" }
      )
    end
  end
end
