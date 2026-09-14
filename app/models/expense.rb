# frozen_string_literal: true

class Expense < ApplicationRecord
  SPLIT_METHODS = %w[equal percentage fixed shares].freeze

  # Null for a personal expense; owner is set instead.
  belongs_to :group, optional: true
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :category, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :voided_by, class_name: "User", optional: true
  belongs_to :rate_locked_by, class_name: "User", optional: true
  belongs_to :currency, foreign_key: :currency_code, primary_key: :code, inverse_of: :expenses
  belongs_to :base_currency, class_name: "Currency", foreign_key: :base_currency_code,
                             primary_key: :code, inverse_of: false

  has_many :expense_payers, dependent: :destroy
  has_many :expense_participants, dependent: :destroy
  has_many :expense_splits, dependent: :destroy
  has_many :payers, through: :expense_payers, source: :user
  has_many :participants, through: :expense_participants, source: :user
  has_many :revisions, as: :revisable, dependent: :destroy

  accepts_nested_attributes_for :expense_payers, :expense_participants, allow_destroy: true

  normalizes :description, with: ->(value) { value.strip }

  validates :description, presence: true, length: { maximum: 200 }
  validates :notes, length: { maximum: 2_000 }
  validates :amount_minor, numericality: { greater_than: 0, only_integer: true }
  validates :base_amount_minor, numericality: { greater_than: 0, only_integer: true }
  validates :exchange_rate, numericality: { greater_than: 0 }
  validates :split_method, inclusion: { in: SPLIT_METHODS }
  validates :spent_on, presence: true

  validate :payer_amounts_match_total
  validate :split_amounts_match_total
  validate :people_belong_to_group

  scope :active, -> { where(voided_at: nil) }
  scope :personal, -> { where(group_id: nil) }
  scope :shared, -> { where.not(group_id: nil) }
  scope :voided, -> { where.not(voided_at: nil) }
  scope :recent_first, -> { order(spent_on: :desc, created_at: :desc, id: :desc) }
  scope :in_period, ->(from, to) { where(spent_on: from..to) }
  scope :involving, ->(user_id) {
    where(id: ExpenseSplit.where(user_id:).select(:expense_id))
      .or(where(id: ExpensePayer.where(user_id:).select(:expense_id)))
  }
  scope :paid_by, ->(user_id) { where(id: ExpensePayer.where(user_id:).select(:expense_id)) }
  scope :shared_with, ->(user_id) { where(id: ExpenseSplit.where(user_id:).select(:expense_id)) }

  scope :rate_locked, -> { where.not(rate_locked_at: nil) }
  scope :awaiting_rate_lock, -> { active.where(rate_locked_at: nil).where("currency_code <> base_currency_code") }

  def personal? = group_id.nil?

  def voided? = voided_at.present?
  def active? = voided_at.nil?

  def rate_locked? = rate_locked_at.present?
  def native_currency? = currency_code == base_currency_code

  # True while the base-currency figures on this expense are only a guide.
  def indicative_rate? = !native_currency? && !rate_locked?

  def amount = MoneyAmount.new(amount_minor, currency)
  def base_amount = MoneyAmount.new(base_amount_minor, base_currency)
  def converted? = currency_code != base_currency_code

  def share_for(user_id)
    split = expense_splits.detect { |s| s.user_id == user_id }
    split ? split.amount : MoneyAmount.zero(currency)
  end

  def base_share_for(user_id)
    split = expense_splits.detect { |s| s.user_id == user_id }
    split ? split.base_amount : MoneyAmount.zero(base_currency)
  end

  def paid_by_label
    names = expense_payers.map { |payer| payer.user.name }
    case names.length
    when 0 then "Nobody"
    when 1 then names.first
    when 2 then names.join(" and ")
    else "#{names.first} and #{names.length - 1} others"
    end
  end

  private

  def payer_amounts_match_total
    payers = expense_payers.reject(&:marked_for_destruction?)
    return if payers.empty?

    total = payers.sum { |payer| payer.amount_minor.to_i }
    return if total == amount_minor

    errors.add(:base, "Payer amounts must add up to the expense total")
  end

  def split_amounts_match_total
    splits = expense_splits.reject(&:marked_for_destruction?)
    return if splits.empty?

    total = splits.sum { |split| split.amount_minor.to_i }
    return if total == amount_minor

    errors.add(:base, "Split amounts must add up to the expense total")
  end

  def people_belong_to_group
    return personal_expense_involves_only_owner if group.blank?

    member_ids = group.group_memberships.pluck(:user_id).to_set
    involved = (expense_payers.reject(&:marked_for_destruction?).map(&:user_id) +
                expense_participants.reject(&:marked_for_destruction?).map(&:user_id)).compact.uniq
    outsiders = involved.reject { |id| member_ids.include?(id) }
    return if outsiders.empty?

    errors.add(:base, "Everyone on an expense must be a member of the group")
  end

  def personal_expense_involves_only_owner
    return errors.add(:base, "A personal expense needs an owner") if owner_id.blank?

    involved = (expense_payers.reject(&:marked_for_destruction?).map(&:user_id) +
                expense_participants.reject(&:marked_for_destruction?).map(&:user_id)).compact.uniq
    return if involved.all? { |id| id == owner_id }

    errors.add(:base, "A personal expense can only involve its owner")
  end
end
