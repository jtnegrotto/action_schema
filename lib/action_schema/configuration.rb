module ActionSchema
  class Configuration
    attr_accessor :base_class, :transform_keys, :type_serializers

    def initialize
      @base_class = ActionSchema::Base
      @transform_keys = nil
      @type_serializers = {}
    end

    def base_class
      if @base_class.is_a?(String)
        @base_class.constantize
      else
        @base_class
      end
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
