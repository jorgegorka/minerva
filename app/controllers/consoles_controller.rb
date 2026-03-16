# frozen_string_literal: true

class ConsolesController < ApplicationController
  skip_before_action :set_current_project

  rescue_from Drive::TmuxNotFoundError, with: :handle_tmux_not_found
  rescue_from Drive::SessionNotFoundError, with: :handle_session_not_found

  def index
    sessions = Drive::Tmux.list_sessions
    @consoles = sessions.map do |session|
      output = Drive::Tmux.capture_pane(session.name, start_line: -5) rescue ""
      state = Drive::PromptDetector.detect(output)
      ConsolePresenter.new(session_info: session, state: state)
    end

    respond_to do |format|
      format.html
      format.json { render json: @consoles.map(&:to_h) }
    end
  end

  def show
    Drive::Tmux.require_session(params[:name])
    session_info = Drive::Tmux.list_sessions.find { |s| s.name == params[:name] }
    raise Drive::SessionNotFoundError.new(params[:name]) unless session_info

    @output = Drive::Tmux.capture_pane(params[:name], start_line: -50)
    @display_lines = @output.lines.last(20).join
    state = Drive::PromptDetector.detect(@output)
    @console = ConsolePresenter.new(session_info: session_info, state: state)
    @processes = Drive::ProcessManager.list_processes(session: params[:name])

    respond_to do |format|
      format.html
      format.json do
        render json: {
          console: @console.to_h,
          output: @display_lines,
          processes: @processes.map(&:to_output_h)
        }
      end
    end
  end

  def destroy
    Drive::Tmux.kill_session(params[:name])
    redirect_to consoles_path, notice: "Session '#{params[:name]}' was terminated."
  end

  def send_keys
    text = params[:text].to_s
    Drive::Tmux.send_keys(params[:name], text, literal: true)
    redirect_to console_path(name: params[:name])
  end

  private

  def handle_tmux_not_found
    respond_to do |format|
      format.html { render :error_state, status: :service_unavailable }
      format.json { render json: { error: "tmux not found" }, status: :service_unavailable }
    end
  end

  def handle_session_not_found(error)
    respond_to do |format|
      format.html { redirect_to consoles_path, alert: error.message }
      format.json { render json: { error: error.message }, status: :not_found }
    end
  end
end
