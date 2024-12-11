module RSpecHelpers
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def helpers
      @helpers ||= []
    end

    def helper(name, lambda_or_proc = nil, &block)
      closure = lambda_or_proc || block
      define_method(name, &closure)
      self.helpers << name
    end
  end
end

RSpec.configure do |config|
  config.include RSpecHelpers
end
