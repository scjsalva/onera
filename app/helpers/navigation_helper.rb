# frozen_string_literal: true

module NavigationHelper
  # One tab. Reads as an icon plus a small label on mobile, an icon and label
  # in a row on desktop.
  def nav_link_to(label, path, active, &icon)
    classes = class_names(
      "group flex flex-1 flex-col items-center justify-center gap-1 rounded-xl px-2 py-2 transition",
      "md:flex-none md:flex-row md:justify-start md:gap-3 md:px-3 md:py-2.5",
      "text-brand-700 md:bg-brand-50" => active,
      "text-ink-500 hover:text-ink-800 active:scale-95 md:hover:bg-ink-100" => !active
    )

    link_to path, class: classes, "aria-current": (active ? "page" : nil) do
      concat tag.svg(capture(&icon), class: class_names("h-6 w-6 transition-transform md:h-5 md:w-5",
                                                        "scale-110 md:scale-100" => active),
                                     fill: "none", stroke: "currentColor",
                                     "stroke-width": active ? "2.4" : "1.9", viewBox: "0 0 24 24")
      concat tag.span(label, class: class_names("text-[11px] font-medium leading-none md:text-sm",
                                                "font-semibold" => active))
    end
  end
end
