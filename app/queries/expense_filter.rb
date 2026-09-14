# frozen_string_literal: true

# Normalises the filter params shared by the group and global expense lists.
# Kept deliberately small: a handful of combinable filters, not a query builder.
class ExpenseFilter
  PERIODS = %w[all today week month year custom].freeze
  PERSONAL = "personal"

  attr_reader :query, :group_id, :person_id, :payer_id, :category_id,
              :currency_code, :period, :from, :to, :min_amount, :max_amount, :status

  def initialize(params = {})
    params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    params = params.with_indifferent_access

    @query = params[:q].to_s.strip.presence
    @group_id = params[:group_id].presence
    @person_id = params[:person_id].presence
    @payer_id = params[:payer_id].presence
    @category_id = params[:category_id].presence
    @currency_code = params[:currency_code].presence
    @period = PERIODS.include?(params[:period]) ? params[:period] : "all"
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    @min_amount = parse_decimal(params[:min_amount])
    @max_amount = parse_decimal(params[:max_amount])
    @status = %w[active voided all].include?(params[:status]) ? params[:status] : "active"
  end

  # "personal" is a scope, not an id: expenses with no group at all.
  def personal? = group_id == PERSONAL

  def group_scope_id = personal? ? nil : group_id

  def date_range
    case period
    when "today" then Date.current..Date.current
    when "week" then Date.current.beginning_of_week..Date.current.end_of_week
    when "month" then Date.current.beginning_of_month..Date.current.end_of_month
    when "year" then Date.current.beginning_of_year..Date.current.end_of_year
    when "custom" then custom_range
    end
  end

  def any?
    [ query, group_id, person_id, payer_id, category_id, currency_code,
      min_amount, max_amount ].any?(&:present?) || period != "all" || status != "active"
  end

  def to_params
    {
      q: query, group_id:, person_id:, payer_id:, category_id:, currency_code:,
      period: (period unless period == "all"), from: from&.to_s, to: to&.to_s,
      min_amount: min_amount&.to_s("F"), max_amount: max_amount&.to_s("F"),
      status: (status unless status == "active")
    }.compact
  end

  def as_json(*) = to_params

  private

  def custom_range
    return if from.nil? && to.nil?

    (from || Date.new(1970, 1, 1))..(to || Date.current.end_of_year)
  end

  def parse_date(value)
    return if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end

  def parse_decimal(value)
    return if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end
end
