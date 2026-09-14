# frozen_string_literal: true

# An immutable amount of money held as an integer count of minor units.
#
# Every monetary value in Onera passes through here. Nothing in the domain is
# allowed to hold money as a Float: the exponent comes from the Currency row,
# so zero-decimal currencies (JPY, KRW) and two-decimal currencies behave
# identically without special-casing at the call sites.
class MoneyAmount
  include Comparable

  attr_reader :minor, :currency

  class CurrencyMismatch < StandardError; end

  def self.zero(currency) = new(0, currency)

  # Builds from a human-entered decimal ("8400.50"), never from a Float.
  def self.from_major(value, currency)
    decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
    new((decimal * currency.subunit_factor).round(0, :half_up).to_i, currency)
  end

  def initialize(minor, currency)
    @minor = minor.to_i
    @currency = currency
    freeze
  end

  def to_major = BigDecimal(minor) / currency.subunit_factor

  def zero? = minor.zero?
  def negative? = minor.negative?
  def positive? = minor.positive?
  def abs = self.class.new(minor.abs, currency)
  def -@ = self.class.new(-minor, currency)

  def +(other)
    ensure_same_currency!(other)
    self.class.new(minor + other.minor, currency)
  end

  def -(other)
    ensure_same_currency!(other)
    self.class.new(minor - other.minor, currency)
  end

  def <=>(other)
    ensure_same_currency!(other)
    minor <=> other.minor
  end

  def format(symbol: true, sign: false)
    formatted = format_digits
    prefix = if negative?
      "-"
    elsif sign && positive?
      "+"
    else
      ""
    end
    "#{prefix}#{symbol ? currency.symbol : ''}#{formatted}"
  end

  def to_s = format

  # For form fields: no grouping, no symbol, and no phantom ".0" on a
  # zero-decimal currency like JPY.
  def to_input
    return minor.to_s if currency.exponent.zero?

    Kernel.format("%.#{currency.exponent}f", to_major)
  end

  def as_json(*)
    { minor:, major: to_major.to_s("F"), currency: currency.code, formatted: format }
  end

  private

  def format_digits
    digits = minor.abs.to_s.rjust(currency.exponent + 1, "0")
    whole = digits[0...(digits.length - currency.exponent)]
    fraction = currency.exponent.zero? ? nil : digits[-currency.exponent..]
    [ whole.reverse.scan(/\d{1,3}/).join(",").reverse, fraction ].compact.join(".")
  end

  def ensure_same_currency!(other)
    return if currency.code == other.currency.code

    raise CurrencyMismatch, "cannot combine #{currency.code} with #{other.currency.code}"
  end
end
