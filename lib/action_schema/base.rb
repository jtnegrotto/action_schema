module ActionSchema
  class FieldError < ActionSchema::Error
    def initialize(field, record)
      @field = field
      @record = record
      super("Field '#{field}' does not exist on record: #{record.inspect}")
    end
  end

  class Base
    class << self
      attr_accessor :schema, :before_render_hooks, :after_render_hooks

      def call(*args, **kwargs, &block)
        new(*args, **kwargs, &block).render
      end

      def before_render_hooks
        @before_render_hooks ||= []
      end

      def after_render_hooks
        @after_render_hooks ||= []
      end

      def before_render(lambda_or_proc = nil, &block)
        self.before_render_hooks << (lambda_or_proc || block)
      end

      def after_render(lambda_or_proc = nil, &block)
        self.after_render_hooks << (lambda_or_proc || block)
      end

      def inherited(subclass)
        subclass.before_render_hooks = before_render_hooks.dup
        subclass.after_render_hooks = after_render_hooks.dup
        subclass.schema = schema.dup
      end

      def field(name, value = nil, as: nil, **options, &block)
        schema[name] = {
          value: block || value || name,
          as: as,
          **options
        }
      end

      def association(name, association_schema = nil, as: nil, **options, &block)
        base_schema_class = ActionSchema.configuration.base_class

        resolved_schema =
          if association_schema.is_a?(Symbol)
            ->(controller) { controller.resolve_schema(association_schema) }
          elsif association_schema.is_a?(Class)
            association_schema
          elsif association_schema.is_a?(Proc)
            Class.new(base_schema_class, &Dalambda[association_schema])
          elsif block_given?
            Class.new(base_schema_class, &block)
          else
            raise ArgumentError, "An association schema or block must be provided"
          end

        schema[name] = {
          association: resolved_schema,
          as: as,
          **options
        }
      end

      def computed(name, lambda_or_proc = nil, &block)
        schema[name] = { computed: true, value: (lambda_or_proc || block) }
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
      renderable = @record_or_collection
      renderable = apply_hooks(:before_render, @record_or_collection)

      output =
        if renderable.respond_to?(:map)
          renderable.map { |record| render_record(record) }
        else
          render_record(renderable)
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

        transformed_key = config[:as] || transform_key(key)

        result[transformed_key] =
          if config[:computed]
            instance_exec(record, context, &Dalambda[config[:value]])
          elsif association = config[:association]
            associated_record_or_collection = record.public_send(key)
            if associated_record_or_collection.nil?
              nil
            else
              resolved_schema = association.is_a?(Proc) ? association.call(controller) : association
              child_context = context.merge(parent: record)
              resolved_schema.new(record.public_send(key), context: child_context, controller: controller).render
            end
          else
            if record.respond_to?(config[:value])
              record.public_send(config[:value])
            else
              raise FieldError.new(config[:value], record)
            end
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
        instance_exec(data, &Dalambda[hook])
        data = @transformed || data
      end
      data
    end

    def transform(data)
      @transformed = data
    end
  end
end
