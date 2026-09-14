# frozen_string_literal: true

module ApplicationHelper
  def page_title(title)
    content_for(:title) { title }
  end

  # A stable colour per person so avatars stay recognisable across screens.
  AVATAR_TONES = %w[
    bg-brand-600 bg-sand-600 bg-positive-600 bg-negative-600
    bg-ink-700 bg-brand-800 bg-brand-400 bg-ink-500
  ].freeze

  def avatar_tone(user) = AVATAR_TONES[user.id % AVATAR_TONES.length]

  def avatar_tag(user, size: :md, ring: false)
    dimensions = { xs: "h-6 w-6 text-[10px]", sm: "h-8 w-8 text-xs",
                   md: "h-10 w-10 text-sm", lg: "h-14 w-14 text-base" }.fetch(size)

    tag.span(user.initials,
             class: class_names("inline-flex shrink-0 items-center justify-center rounded-full",
                                "font-semibold text-white select-none", dimensions,
                                avatar_tone(user), "ring-2 ring-white" => ring),
             title: user.name)
  end

  def money_tag(money, tone: :auto, size: :base, sign: false)
    tone = money.negative? ? :negative : (money.positive? ? :positive : :neutral) if tone == :auto

    colour = { positive: "text-positive-600", negative: "text-negative-600",
               neutral: "text-ink-500", plain: "text-ink-900" }.fetch(tone)
    scale = { xs: "text-xs", sm: "text-sm", base: "text-base", lg: "text-lg",
              xl: "text-xl", "2xl": "text-2xl", "3xl": "text-3xl" }.fetch(size)

    tag.span(money.format(sign:), class: class_names("tnum font-semibold", colour, scale))
  end

  def relative_day(date)
    case date
    when Date.current then "Today"
    when Date.yesterday then "Yesterday"
    else date.year == Date.current.year ? date.strftime("%-d %b") : date.strftime("%-d %b %Y")
    end
  end

  def category_pill(category)
    return tag.span("Uncategorised", class: "pill bg-ink-200/70 text-ink-600") if category.nil?

    tones = {
      "brand" => "bg-brand-100 text-brand-800", "sand" => "bg-sand-100 text-sand-600",
      "positive" => "bg-positive-100 text-positive-700", "negative" => "bg-negative-100 text-negative-700",
      "ink" => "bg-ink-200/70 text-ink-700"
    }
    tag.span(category.name, class: class_names("pill", tones.fetch(category.color, tones["ink"])))
  end

  def currency_options
    Currency.active.ordered.map { |currency| [ "#{currency.code} · #{currency.symbol}", currency.code ] }
  end

  def debt_json(debt)
    {
      from: { id: debt.from_user.id, name: debt.from_user.name,
              initials: debt.from_user.initials, tone: avatar_tone(debt.from_user) },
      to: { id: debt.to_user.id, name: debt.to_user.name,
            initials: debt.to_user.initials, tone: avatar_tone(debt.to_user) },
      minor: debt.amount_minor,
      formatted: debt.amount.format
    }
  end

  # Props for Vue components are passed as JSON strings on the custom element.
  def vue_json(value) = value.to_json
end
