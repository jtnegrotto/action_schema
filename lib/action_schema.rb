# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/class/attribute"

require_relative "action_schema/version"
require_relative "action_schema/configuration"
require_relative "action_schema/base"
require_relative "action_schema/controller"
require_relative "action_schema/railtie" if defined?(Rails)

module ActionSchema
  class Error < StandardError; end
  # Your code goes here...
end
