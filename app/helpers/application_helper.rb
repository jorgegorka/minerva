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
end
