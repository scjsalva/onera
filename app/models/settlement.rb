# frozen_string_literal: true

# A real-world payment between two people. Settlements move balances but never
# touch the expenses that created them.
class Settlement < ApplicationRecord
  belongs_to :group
  belongs_to :payer, class_name: "User", inverse_of: :settlements_made
  belongs_to :recipient, class_name: "User", inverse_of: :settlements_received
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :voided_by, class_name: "User", optional: true
  belongs_to :currency, foreign_key: :currency_code, primary_key: :code, inverse_of: :settlements
  belongs_to :base_currency, class_name: "Currency", foreign_key: :base_currency_code,
                             primary_key: :code, inverse_of: false

  # Set when a settlement clears a consolidated, rate-locked balance rather
  # than a balance held natively in one currency.
  belongs_to :settles_currency, class_name: "Currency", foreign_key: :settles_currency_code,
                                primary_key: :code, optional: true, inverse_of: false

  has_many :revisions, as: :revisable, dependent: :destroy

  validates :amount_minor, numericality: { greater_than: 0, only_integer: true }
  validates :base_amount_minor, numericality: { greater_than: 0, only_integer: true }
  validates :exchange_rate, numericality: { greater_than: 0 }
  validates :settled_on, presence: true
  validates :note, length: { maximum: 500 }
  validates :payment_method, length: { maximum: 60 }
  validate :parties_are_distinct
  validate :parties_belong_to_group

  scope :active, -> { where(voided_at: nil) }
  scope :recent_first, -> { order(settled_on: :desc, created_at: :desc, id: :desc) }
  scope :involving, ->(user_id) { where(payer_id: user_id).or(where(recipient_id: user_id)) }
  scope :in_period, ->(from, to) { where(settled_on: from..to) }

  def voided? = voided_at.present?

  def amount = MoneyAmount.new(amount_minor, currency)
  def base_amount = MoneyAmount.new(base_amount_minor, base_currency)
  def converted? = currency_code != base_currency_code

  def summary = "#{payer.name} paid #{recipient.name}"

  private

  def parties_are_distinct
    return if payer_id.blank? || payer_id != recipient_id

    errors.add(:recipient_id, "must be someone other than the payer")
  end

  def parties_belong_to_group
    return if group.blank?

    member_ids = group.group_memberships.pluck(:user_id).to_set
    return if [ payer_id, recipient_id ].compact.all? { |id| member_ids.include?(id) }

    errors.add(:base, "Both people must be members of the group")
  end
end
