# frozen_string_literal: true

class ConsolePresenter
  attr_reader :session_info, :state

  delegate :name, :windows, :created, :attached, to: :session_info

  def initialize(session_info:, state: :unknown)
    @session_info = session_info
    @state = state
  end

  def status_label
    Drive::PromptDetector.status_label(state)
  end

  def status_css
    Drive::PromptDetector.status_css_class(state)
  end

  def attached_label
    attached ? "Attached" : "Detached"
  end

  def to_h
    {
      name: name,
      windows: windows,
      created: created,
      attached: attached,
      state: state,
      status_label: status_label,
      status_css: status_css
    }
  end
end
