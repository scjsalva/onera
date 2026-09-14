# frozen_string_literal: true

require "test_helper"

# Randomised invariant checks. The rest of the suite asserts specific figures;
# this one throws awkward shapes at the ledger - odd totals, currencies with no
# subunit, uneven shares, more payers than participants - and asserts the
# things that must never stop being true whatever the numbers are.
class MoneyConservationTest < ActiveSupport::TestCase
  # Fixed so a failure is reproducible; override to sweep for shapes this one
  # happens to miss (MONEY_SEED=n bin/rails test ...).
  SEED = (ENV["MONEY_SEED"] || 20_260_914).to_i
  SPLIT_METHODS = %w[equal shares percentage].freeze

  setup do
    @random = Random.new(SEED)
    @people = 5.times.map { |i| create_user(name: "Person #{i}", username: "person#{i}") }
  end

  test "every generated expense conserves its total, in its own currency and the group's" do
    %w[PHP JPY USD].each do |code|
      group = create_group(name: "Trip #{code}", currency: code, members: @people, creator: @people.first)
      currency = Currency.find(code)

      40.times do
        expense = random_expense(group, currency)

        assert_equal expense.amount_minor, expense.expense_splits.sum(&:amount_minor),
                     "splits drifted from the total on #{describe(expense)}"
        assert_equal expense.amount_minor, expense.expense_payers.sum(&:amount_minor),
                     "payers drifted from the total on #{describe(expense)}"
        assert_equal expense.base_amount_minor, expense.expense_splits.sum(&:base_amount_minor),
                     "converted splits drifted on #{describe(expense)}"
        assert_equal expense.base_amount_minor, expense.expense_payers.sum(&:base_amount_minor),
                     "converted payers drifted on #{describe(expense)}"
        assert expense.expense_splits.none? { |s| s.amount_minor.negative? },
               "a negative share appeared on #{describe(expense)}"
      end
    end
  end

  test "a group's positions always sum to zero in every currency it has used" do
    group = create_group(name: "Mixed", currency: "PHP", members: @people, creator: @people.first)

    30.times { random_expense(group, Currency.find(%w[PHP JPY USD].sample(random: @random))) }
    10.times { random_settlement(group) }

    balances = BalanceCalculator.new(group)
    balances.currencies.each do |currency|
      total = balances.positions_in(currency).sum(&:net_minor)
      assert_equal 0, total, "#{currency.code} positions summed to #{total}, not zero"
    end
  end

  test "simplified debts settle everybody to zero and never invent money" do
    group = create_group(name: "Simplify", currency: "PHP", members: @people, creator: @people.first)

    25.times { random_expense(group, php) }
    5.times { random_settlement(group) }

    balances = BalanceCalculator.new(group)
    simplified = balances.simplified_debts(php)

    # Applying the suggested payments must leave every position at zero.
    after = balances.positions_in(php).to_h { |position| [ position.user.id, position.net_minor ] }
    simplified.each do |debt|
      after[debt.from_user.id] += debt.amount_minor
      after[debt.to_user.id] -= debt.amount_minor
    end
    assert after.values.all?(&:zero?), "simplifying left people out of balance: #{after.inspect}"

    # And it must never move more money than the debts it replaces.
    pairwise = balances.pairwise_debts(php).sum(&:amount_minor)
    assert_operator simplified.sum(&:amount_minor), :<=, pairwise,
                    "simplifying moved more money than paying pairwise would"
  end

  test "a voided expense leaves no trace in the balances" do
    group = create_group(name: "Void", currency: "PHP", members: @people, creator: @people.first)

    15.times { random_expense(group, php) }
    before = BalanceCalculator.new(group).positions_in(php).to_h { |p| [ p.user.id, p.net_minor ] }

    victim = random_expense(group, php)
    refute_equal before, BalanceCalculator.new(group).positions_in(php).to_h { |p| [ p.user.id, p.net_minor ] }

    ExpenseVoider.call(expense: victim, actor: @people.first)
    after = BalanceCalculator.new(group).positions_in(php).to_h { |p| [ p.user.id, p.net_minor ] }

    assert_equal before, after, "voiding did not put the balances back"
  end

  private

  def describe(expense)
    "#{expense.split_method} #{expense.amount_minor} #{expense.currency_code} " \
      "across #{expense.expense_splits.size} people"
  end

  def random_expense(group, currency)
    participants = @people.sample(@random.rand(1..@people.size), random: @random)
    payers = @people.sample(@random.rand(1..3), random: @random)
    method = SPLIT_METHODS.sample(random: @random)

    # Awkward on purpose: totals that do not divide evenly by anything.
    total_minor = @random.rand(1..9_999_99)
    total = MoneyAmount.new(total_minor, currency).to_input

    add_expense(
      group:, actor: payers.first,
      amount: total,
      currency_code: currency.code,
      split_method: method,
      payers: payer_rows(payers, total_minor, currency),
      participants: participant_rows(participants, method),
      description: "Random #{method}"
    )
  end

  # Whole amounts that add up exactly to the total, with the remainder landing
  # on the last payer - the same shape the form posts.
  def payer_rows(payers, total_minor, currency)
    return [ { user_id: payers.first.id, amount: MoneyAmount.new(total_minor, currency).to_input } ] if payers.one?

    each = total_minor / payers.size
    amounts = Array.new(payers.size - 1, each) << (total_minor - each * (payers.size - 1))
    payers.each_with_index.map do |payer, index|
      { user_id: payer.id, amount: MoneyAmount.new(amounts[index], currency).to_input }
    end
  end

  def participant_rows(participants, method)
    case method
    when "equal"
      participants.map { |p| { user_id: p.id, split_value: nil } }
    when "shares"
      participants.map { |p| { user_id: p.id, split_value: @random.rand(1..9).to_s } }
    when "percentage"
      weights = participants.map { @random.rand(1..100) }
      total = weights.sum
      # Whole percentages that add to exactly 100.
      percents = weights.map { |w| (w * 100) / total }
      percents[-1] += 100 - percents.sum
      participants.each_with_index.map { |p, i| { user_id: p.id, split_value: percents[i].to_s } }
    end
  end

  def random_settlement(group)
    payer, recipient = @people.sample(2, random: @random)
    SettlementCreator.call(
      group:, actor: payer,
      params: {
        payer_id: payer.id, recipient_id: recipient.id,
        amount: MoneyAmount.new(@random.rand(1..50_000), php).to_input,
        currency_code: "PHP", paid_on: Date.current
      }
    )
  end
end
