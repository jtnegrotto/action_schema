require "rails"
require "action_controller/railtie"

module DummyApp
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.log_level = :fatal
    config.active_support.deprecation = :silence
  end
end

DummyApp::Application.initialize!
