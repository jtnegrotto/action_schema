# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/class/attribute"

module ActionSchema
  class Error < StandardError; end
end

require_relative "action_schema/version"
require_relative "action_schema/dalambda"
require_relative "action_schema/configuration"
require_relative "action_schema/base"
require_relative "action_schema/controller"
require_relative "action_schema/railtie" if defined?(Rails)
