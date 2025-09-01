RubyLLM.configure do |config|
  config.openrouter_api_key = Rails.application.credentials.dig(:openrouter, :api_key)
  config.ollama_api_base = "http://localhost:11434/v1"

  config.default_model = "openai/gpt-5-nano"
end

