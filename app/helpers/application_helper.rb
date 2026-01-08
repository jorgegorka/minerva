module ApplicationHelper
  # Renders an icon using the CSS mask-based icon system.
  # The icon inherits color from its parent via currentColor.
  #
  # @param name [String] The icon name (e.g., "check", "pencil")
  # @param options [Hash] Additional HTML attributes (e.g., class:)
  # @return [String] HTML span element with icon classes
  #
  # @example Basic usage
  #   icon_tag("check")
  #   # => <span class="icon icon--check" aria-hidden="true"></span>
  #
  # @example With additional classes
  #   icon_tag("pencil", class: "txt-subtle")
  #   # => <span class="icon icon--pencil txt-subtle" aria-hidden="true"></span>
  def icon_tag(name, **options)
    css_classes = [ "icon", "icon--#{name}", options.delete(:class) ].compact.join(" ")
    tag.span(class: css_classes, aria: { hidden: true }, **options)
  end

  # Returns CSS classes for navigation links with active state detection.
  #
  # @param target_controller [String] The controller name to check against
  # @return [String] CSS classes including active modifier if current
  #
  # @example
  #   nav_link_class("categories")
  #   # => "site-nav__link site-nav__link--active" (if on categories page)
  #   # => "site-nav__link" (if on other page)
  def nav_link_class(target_controller)
    base_class = "site-nav__link"
    active_class = "site-nav__link--active"

    if controller_name == target_controller
      "#{base_class} #{active_class}"
    else
      base_class
    end
  end
end
