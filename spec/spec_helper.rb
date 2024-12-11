# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
end

ENV["RAILS_ENV"] = "test"
require "rails" # Require Rails first so that the Railtie loads
require "action_schema"
require "dummy_app/config/application"
require "rspec/rails"
require "pry"
require "pry-nav"
require "ostruct"
require "pp"

require "support/helpers"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.render_views
end
