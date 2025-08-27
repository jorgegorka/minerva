class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def current_user
    # TODO: Implement proper user authentication
    @current_user ||= Struct.new(:id).new(1)
  end
end
