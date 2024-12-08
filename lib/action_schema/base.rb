module ActionSchema
  class Base
    class << self
      attr_accessor :schema, :before_render_hooks, :after_render_hooks

      def before_render(&block)
        self.before_render_hooks ||= []
        before_render_hooks << block
      end

      def after_render(&block)
        self.after_render_hooks ||= []
        after_render_hooks << block
      end

      def inherited(subclass)
        subclass.before_render_hooks = (before_render_hooks || []).dup
        subclass.after_render_hooks = (after_render_hooks || []).dup
        subclass.schema = schema.dup
      end

      def field(name, value = nil, **options, &block)
        schema[name] = { value: block || value || name, **options }
      end

      def association(name, schema_definition = nil, &block)
        base_schema_class = ActionSchema.configuration.base_class

        resolved_schema = 
          if schema_definition.is_a?(Symbol)
            ->(controller) { controller.resolve_schema(schema_definition) }
          elsif schema_definition.is_a?(Class)
            schema_definition
          elsif block_given?
            Class.new(base_schema_class, &block)
          else
            raise ArgumentError, "An association schema or block must be provided"
          end

        schema[name] = { association: resolved_schema }
      end

      def computed(name, &block)
        schema[name] = { computed: true, value: block }
      end

      def fields(*names)
        names.each { |name| field(name) }
      end

      def omit(*names)
        names.each { |name| schema.delete(name) }
      end

      def schema
        @schema ||= {}
      end

      def parse(data)
        raise NotImplementedError, "Parsing is not yet implemented"
      end
    end

    attr_reader :record_or_collection, :context, :controller

    def initialize(record_or_collection, context: {}, controller: nil)
      @record_or_collection = record_or_collection
      @context = context
      @controller = controller
    end

    def render
      record_or_collection = apply_hooks(:before_render, @record_or_collection)

      output =
        if record_or_collection.respond_to?(:map)
          record_or_collection.map { |record| render_record(record) }
        else
          render_record(record_or_collection)
        end

      apply_hooks(:after_render, output)
    end

    private

    def render_record(record)
      self.class.schema.each_with_object({}) do |(key, config), result|
        if_condition = config[:if]
        unless_condition = config[:unless]

        next if if_condition && !instance_exec(record, &if_condition)
        next if unless_condition && instance_exec(record, &unless_condition)

        transformed_key = transform_key(key)

        result[transformed_key] =
          if config[:computed]
            instance_exec(record, context, &config[:value])
          elsif association = config[:association]
            resolved_schema = association.is_a?(Proc) ? association.call(controller) : association
            child_context = context.merge(parent: record)
            resolved_schema.new(record.public_send(key), context: child_context, controller: controller).render
          else
            record.public_send(config[:value])
          end
      end
    end

    def transform_key(key)
      transform_keys = ActionSchema.configuration.transform_keys
      transform_keys ? transform_keys.call(key) : key
    end

    def apply_hooks(type, data)
      hooks = self.class.public_send("#{type}_hooks") || []
      hooks.each do |hook|
        @transformed = nil
        instance_exec(data, &hook)
        data = @transformed || data
      end
      data
    end

    def transform data
      @transformed = data
    end
  end
end
