# frozen_string_literal: true

require "test_helper"

# Batching the aggregates is only worth anything if it cannot change an answer.
# This builds awkward groups - several currencies, uneven splits, settlements,
# a voided expense, somebody who joined and spent nothing - and asserts the
# batched calculator agrees with the one-group-at-a-time one on every figure.
class BalanceBatchTest < ActiveSupport::TestCase
  setup do
    @random = Random.new(4_711)
    @people = 5.times.map { |i| create_user(name: "Person #{i}", username: "bb#{i}") }
    @groups = build_groups
  end

  test "a batched calculator matches an unbatched one on every figure" do
    batch = BalanceCalculator::Batch.new(@groups)

    @groups.each do |group|
      alone = BalanceCalculator.new(group)
      together = batch.for(group)

      assert_equal alone.members.map(&:id), together.members.map(&:id), "members differ in #{group.name}"
      assert_equal alone.currencies.map(&:code), together.currencies.map(&:code),
                   "currencies differ in #{group.name}"

      alone.currencies.each do |currency|
        assert_equal alone.total_spend(currency).minor, together.total_spend(currency).minor,
                     "total spend differs in #{group.name} #{currency.code}"
        assert_equal alone.total_settled(currency).minor, together.total_settled(currency).minor,
                     "settled total differs in #{group.name} #{currency.code}"
        assert_equal alone.active_in?(currency.code), together.active_in?(currency.code),
                     "activity differs in #{group.name} #{currency.code}"
        assert_equal positions(alone, currency), positions(together, currency),
                     "positions differ in #{group.name} #{currency.code}"
        assert_equal debts(alone.pairwise_debts(currency)), debts(together.pairwise_debts(currency)),
                     "pairwise debts differ in #{group.name} #{currency.code}"
        assert_equal debts(alone.simplified_debts(currency)), debts(together.simplified_debts(currency)),
                     "simplified debts differ in #{group.name} #{currency.code}"
      end
    end
  end

  test "a group with nothing in it batches to the same empty answer" do
    empty = create_group(name: "Empty", members: @people, creator: @people.first)
    together = BalanceCalculator::Batch.new([ empty ]).for(empty)
    alone = BalanceCalculator.new(empty)

    assert_equal alone.currencies.map(&:code), together.currencies.map(&:code)
    assert_equal positions(alone, php), positions(together, php)
    assert together.standings.all?(&:settled?)
  end

  private

  def positions(calculator, currency)
    calculator.positions_in(currency).map do |position|
      [ position.user.id, position.paid_minor, position.share_minor,
        position.settled_paid_minor, position.settled_received_minor, position.net_minor ]
    end
  end

  def debts(list)
    list.map { |debt| [ debt.from_user.id, debt.to_user.id, debt.amount_minor ] }.sort
  end

  def build_groups
    groups = %w[PHP JPY].map do |code|
      create_group(name: "Trip #{code}", currency: code, members: @people, creator: @people.first)
    end

    groups.each_with_index do |group, index|
      6.times do |n|
        currency = n.even? ? group.base_currency : usd
        participants = @people.sample(@random.rand(2..@people.size), random: @random)
        payers = @people.sample(@random.rand(1..2), random: @random)
        total_minor = @random.rand(101..99_999)

        expense = add_expense(
          group:, actor: payers.first,
          amount: MoneyAmount.new(total_minor, currency).to_input,
          currency_code: currency.code,
          split_method: n % 3 == 1 ? "shares" : "equal",
          payers: payer_rows(payers, total_minor, currency),
          participants: participants.map do |person|
            { user_id: person.id, split_value: (n % 3 == 1 ? @random.rand(1..5).to_s : nil) }
          end
        )

        # One voided expense per group: it must not reach any figure.
        ExpenseVoider.call(expense:, actor: @people.first) if n == 5
      end

      SettlementCreator.call(group:, actor: @people[1], params: {
        payer_id: @people[1].id, recipient_id: @people[0].id,
        amount: "37.50", currency_code: group.base_currency_code, paid_on: Date.current
      })

      # Somebody who is in the group but has spent nothing.
      GroupMembership.create!(group:, user: create_user(name: "Quiet #{index}", username: "quiet#{index}"))
    end

    groups
  end

  def payer_rows(payers, total_minor, currency)
    return [ { user_id: payers.first.id, amount: MoneyAmount.new(total_minor, currency).to_input } ] if payers.one?

    first = total_minor / 2
    [ { user_id: payers[0].id, amount: MoneyAmount.new(first, currency).to_input },
      { user_id: payers[1].id, amount: MoneyAmount.new(total_minor - first, currency).to_input } ]
  end
end
