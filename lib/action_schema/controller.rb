module ActionSchema
  module Controller
    extend ActiveSupport::Concern

    included do
      class_attribute :tagged_schemas, default: {}
      class_attribute :default_schema_context, default: {}
    end

    class_methods do
      def schema(name = :default, context: {}, &block)
        schema_class = create_schema_class(context: context, closure: block)
        tagged_schemas[name.to_sym] = schema_class
      end

      def schema_context(context)
        self.default_schema_context = merged_context(default_schema_context, context)
      end

      private

      def create_schema_class(context: {}, closure: nil)
        raise ArgumentError, "You must provide a block to define the schema" unless closure
        base_schema_class = ActionSchema.configuration.base_class
        final_context = merged_context(default_schema_context, context)
        dalambda = Dalambda[closure]
        Class.new(base_schema_class, &dalambda).tap do |schema_class|
          schema_class.context.merge!(final_context)
          schema_class.tagged_schemas = tagged_schemas
        end
      end

      def merged_context(*contexts)
        contexts.reduce({}, :merge)
      end
    end

    def schema_for(name_or_with, with: nil, context: {})
      name = case name_or_with
      when Symbol, String
               name_or_with.to_sym
      when nil
               :default
      else
               with = name_or_with
               :default
      end

      schema_class = tagged_schemas[name.to_sym]
      raise ArgumentError, "Schema `#{name}` is not defined for #{self.class.name}" if schema_class.nil?
      create_schema(schema_class, with: with, context: context)
    end

    def schema(with = nil, context: {}, &block)
      schema_class = self.class.send(:create_schema_class, context: context, closure: block)
      create_schema(schema_class, with: with, context: context)
    end

    private

    def create_schema(schema_class, with: nil, context: {})
      schema_class.new(with, context: context)
    end
  end
end
