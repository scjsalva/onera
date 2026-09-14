# frozen_string_literal: true

# A User is one real person, globally, across every group they appear in.
#
# There is no authentication yet; `Current.user` is established from a session
# user picker. When authentication arrives it should replace only how
# Current.user is set - this record stays the domain identity.
class User < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  # No :recoverable - recovery is by offline code, so the app needs no mail
  # service to be usable. No :validatable either: it insists on an email, and
  # here email is optional until someone chooses to add one.
  devise :database_authenticatable, :rememberable

  USERNAME_FORMAT = /\A[a-z0-9][a-z0-9._-]{2,29}\z/

  # Sign in with either. Devise looks this up through :login.
  attr_writer :login

  def login = @login || username || email

  belongs_to :preferred_currency, class_name: "Currency", foreign_key: :preferred_currency_code,
                                  primary_key: :code, inverse_of: false

  has_many :recovery_codes, dependent: :delete_all
  has_many :notifications, dependent: :delete_all

  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
  has_many :created_groups, class_name: "Group", foreign_key: :created_by_id,
                            inverse_of: :created_by, dependent: :nullify

  has_many :expense_payers, dependent: :restrict_with_error
  has_many :expense_participants, dependent: :restrict_with_error
  has_many :expense_splits, dependent: :restrict_with_error
  has_many :paid_expenses, through: :expense_payers, source: :expense
  has_many :shared_expenses, through: :expense_splits, source: :expense

  has_many :settlements_made, class_name: "Settlement", foreign_key: :payer_id,
                              inverse_of: :payer, dependent: :restrict_with_error
  has_many :settlements_received, class_name: "Settlement", foreign_key: :recipient_id,
                                  inverse_of: :recipient, dependent: :restrict_with_error

  normalizes :email, with: ->(email) { email.strip.downcase.presence }
  normalizes :name, with: ->(name) { name.strip }
  normalizes :username, with: ->(username) { username.strip.downcase.presence }

  validates :name, presence: true, length: { maximum: 120 }
  validates :username, presence: true,
                       format: { with: USERNAME_FORMAT,
                                 message: "must be 3-30 characters: letters, numbers, dots, dashes or underscores" },
                       uniqueness: { case_sensitive: false }
  # Optional, but must be usable and unique when given - it is a login too.
  validates :email, format: { with: EMAIL_FORMAT }, allow_blank: true,
                    uniqueness: { case_sensitive: false }, length: { maximum: 255 }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :password, confirmation: true
  validate :date_of_birth_is_in_the_past

  scope :ordered, -> { order(:name, :id) }
  # Anonymized people are excluded from everywhere you pick a person. They
  # still resolve through their associations, so expenses and group
  # membership keep working.
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archived? = archived_at.present?

  # Devise checks this before signing anyone in. A closed account keeps its
  # row for the sake of the expenses that reference it, but can never be
  # used again.
  def active_for_authentication? = super && !archived?

  def inactive_message = archived? ? :account_closed : super

  def unused_recovery_codes = recovery_codes.unused.count
  def recovery_codes_issued? = recovery_codes.exists?

  # Derived, never stored - a stored age is wrong the day after it is written.
  def age(on: Date.current)
    return if date_of_birth.blank?

    on.year - date_of_birth.year - (on.strftime("%m%d") < date_of_birth.strftime("%m%d") ? 1 : 0)
  end

  AVATAR_STYLE = "notionists-neutral"
  AVATAR_HOST = "https://api.dicebear.com/9.x"

  # Deterministic from the username, so the same person is the same face on
  # every device with nothing stored. If the service is unreachable the UI
  # falls back to the initials underneath, so this is decoration, not a
  # dependency.
  def avatar_url(size: 96)
    return nil if archived?

    "#{AVATAR_HOST}/#{AVATAR_STYLE}/svg?" + {
      seed: username.presence || "user-#{id}",
      size:,
      backgroundColor: "transparent",
      radius: 50
    }.to_query
  end

  def initials
    # Anonymized people all share a name, so their initials come from their
    # number instead - two of them must never look like the same person.
    return "R#{archived_ordinal}" if archived?

    name.split.first(2).map { |part| part[0] }.join.upcase
  end

  def member_of?(group) = group_memberships.exists?(group_id: group.id)

  def needs_email? = email.blank?

  # Devise's lookup, widened so one field accepts either identifier.
  def self.find_for_database_authentication(conditions)
    login = conditions[:login].to_s.strip.downcase
    return nil if login.blank?

    active.where("lower(username) = :login OR lower(email) = :login", login:).first
  end

  private

  def date_of_birth_is_in_the_past
    return if date_of_birth.blank? || date_of_birth <= Date.current

    errors.add(:date_of_birth, "can't be in the future")
  end
end
