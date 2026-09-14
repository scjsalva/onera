# frozen_string_literal: true

# Applies an ExpenseFilter to a scope entirely in SQL. Nothing is loaded into
# Ruby to be filtered out again.
class ExpenseQuery
  def initialize(scope = Expense.all, filter: ExpenseFilter.new)
    @scope = scope
    @filter = filter
  end

  def call
    relation = base_scope
    relation = apply_status(relation)
    relation = apply_search(relation)
    relation = apply_associations(relation)
    relation = apply_dates(relation)
    apply_amounts(relation)
  end

  private

  attr_reader :scope, :filter

  def base_scope
    relation = scope.left_joins(:category, :group)
    # Amount bounds compare against the converted figure, which is held in the
    # base currency's minor units - and those differ per currency, so the
    # currency row has to come along to know where the decimal point is.
    return relation unless filter.min_amount.present? || filter.max_amount.present?

    relation.joins("INNER JOIN currencies base_currencies " \
                   "ON base_currencies.code = expenses.base_currency_code")
  end

  def apply_status(relation)
    case filter.status
    when "active" then relation.where(expenses: { voided_at: nil })
    when "voided" then relation.where.not(expenses: { voided_at: nil })
    else relation
    end
  end

  def apply_search(relation)
    return relation if filter.query.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(filter.query)}%"

    relation.where(<<~SQL.squish, term:)
      expenses.description ILIKE :term
        OR expenses.notes ILIKE :term
        OR categories.name ILIKE :term
        OR groups.name ILIKE :term
        OR EXISTS (
          SELECT 1 FROM expense_payers ep
          JOIN users pu ON pu.id = ep.user_id
          WHERE ep.expense_id = expenses.id AND pu.name ILIKE :term
        )
        OR EXISTS (
          SELECT 1 FROM expense_splits es
          JOIN users su ON su.id = es.user_id
          WHERE es.expense_id = expenses.id AND su.name ILIKE :term
        )
    SQL
  end

  def apply_associations(relation)
    if filter.personal?
      relation = relation.where(expenses: { group_id: nil })
    elsif filter.group_scope_id.present?
      relation = relation.where(expenses: { group_id: filter.group_scope_id })
    end
    relation = relation.where(expenses: { category_id: filter.category_id }) if filter.category_id.present?
    relation = relation.where(expenses: { currency_code: filter.currency_code }) if filter.currency_code.present?
    relation = relation.merge(Expense.involving(filter.person_id)) if filter.person_id.present?
    relation = relation.merge(Expense.paid_by(filter.payer_id)) if filter.payer_id.present?
    relation
  end

  def apply_dates(relation)
    range = filter.date_range
    range ? relation.where(expenses: { spent_on: range }) : relation
  end

  # Compared against the group-currency figure so a mixed-currency list stays
  # comparable. Scaling by the currency's own exponent rather than assuming
  # two decimals: a ¥1,000 expense is 1000 minor units, not 100000, and a flat
  # multiplier silently excluded every zero-decimal currency.
  def apply_amounts(relation)
    if filter.min_amount.present?
      relation = relation.where(
        "expenses.base_amount_minor >= ? * power(10, base_currencies.exponent)", filter.min_amount
      )
    end

    if filter.max_amount.present?
      relation = relation.where(
        "expenses.base_amount_minor <= ? * power(10, base_currencies.exponent)", filter.max_amount
      )
    end

    relation
  end
end
