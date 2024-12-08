module ActionSchema
  module Controller
    extend ActiveSupport::Concern

    included do
      class_attribute :action_schemas, default: {}
      class_attribute :default_schema_context, default: {}
    end

    class_methods do
      def schema(name = :default, &block)
        action_schemas[name] = Class.new(ActionSchema.configuration.base_class, &block)
      end

      def schema_context(context)
        self.default_schema_context = self.default_schema_context.merge(context)
      end
    end

    def schema_context
      resolve_schema_context(self.class.default_schema_context)
    end

    def schema_for(record_or_collection, schema_name = :default, context: {}, &block)
      combined_schema_context = schema_context.merge(resolve_schema_context(context))

      schema_definition = 
        if block_given?
          Class.new(ActionSchema.configuration.base_class, &block)
        elsif schema_name.is_a?(Class)
          schema_name
        else
          self.class.action_schemas[schema_name]
        end

      raise ArgumentError, "Schema `#{schema_name}` not defined" unless schema_definition

      schema_definition.new(record_or_collection, context: combined_schema_context, controller: self).render
    end

    def resolve_schema(schema_name_or_class)
      case schema_name_or_class
      when Symbol
        self.class.action_schemas[schema_name_or_class] ||
          raise(ArgumentError, "Schema `#{schema_name_or_class}` not defined")
      when Class
        schema_name_or_class
      else
        raise ArgumentError, "Invalid schema: must be a Symbol or Class"
      end
    end

    private

    def resolve_schema_context(context)
      context.transform_values do |value|
        if value.is_a?(Proc)
          instance_exec(&value)
        else
          value
        end
      end
    end
  end
end