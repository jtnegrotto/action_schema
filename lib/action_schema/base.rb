module ActionSchema
  # Errors raised during rendering should inherit from this class
  class RenderError < ActionSchema::Error; end

  class InvalidFieldType < RenderError
    def initialize(field, type)
      @field = field
      @type = type
      super("Invalid field type #{type.inspect} for field '#{field}'")
    end
  end

  class FieldMissing < RenderError
    def initialize(field, record)
      @field = field
      @record = record
      super("Field '#{field}' does not exist on record: #{record.inspect}")
    end
  end

  class SchemaNotFound < RenderError
    def initialize(tag)
      @tag = tag
      super("Schema with tag '#{tag}' not found")
    end
  end

  class InvalidSchemaValue < RenderError
    def initialize(value)
      @value = value
      super("Invalid schema value: #{value.inspect}")
    end
  end

  class Base
    class_attribute :schema, default: {}
    class_attribute :hooks, default: { before_render: [], after_render: [] }
    class_attribute :context, default: {}
    class_attribute :tagged_schemas, default: {}

    class << self
      def render(renderable, context: {})
        new(renderable, context: context).render
      end

      def parse(...)
        raise NotImplementedError
      end

      def inherited(subclass)
        subclass.schema = schema.dup
        subclass.hooks = hooks.transform_values(&:dup)
        subclass.context = context.dup
        subclass.tagged_schemas = tagged_schemas.dup
      end

      def field(name, **options)
        schema[name] = { type: :field, value: name, **options }
      end

      def fields(*names, **options)
        names.each { |name| field(name, **options) }
      end

      def omit(*names)
        names.each { |name| schema.delete(name) }
      end

      def computed(name, lambda_or_proc = nil, &block)
        closure = lambda_or_proc || block
        raise ArgumentError, "A lambda, proc, or block must be provided" unless closure
        schema[name] = { type: :computed, value: closure }
      end

      def association(name, schema_or_identifier = nil, **options, &block)
        value = schema_or_identifier || block
        raise ArgumentError, "A schema, tag, or block must be provided" unless value
        schema[name] = { type: :association, value: value, **options }
      end

      def before_render(lambda_or_proc = nil, &block)
        closure = lambda_or_proc || block
        raise ArgumentError, "A lambda, proc, or block must be provided" unless closure
        hooks[:before_render] << closure
      end

      def after_render(lambda_or_proc = nil, &block)
        closure = lambda_or_proc || block
        raise ArgumentError, "A lambda, proc, or block must be provided" unless closure
        hooks[:after_render] << closure
      end

      def deconstruct_keys
        schema
      end
    end

    attr_reader :renderable, :context

    def initialize(renderable = nil, context: {})
      @renderable = renderable
      @context = self.class.context.merge(context)
    end

    def render
      data = @renderable
      data = apply_hooks(:before_render, data)

      output =
        if data.respond_to?(:map)
          data.map { |record| render_record(record) }
        else
          render_record(data)
        end

      apply_hooks(:after_render, output)
    end

    def as_json(*)
      render
    end

    def to_json(*)
      as_json.to_json
    end

    def merge!(hash)
      tap { merged_attributes.merge!(hash) }
    end

    private

    def merged_attributes
      @merged_attributes ||= {}
    end

    def render_record(record)
      attributes = self.class.schema.each_with_object({}) do |(key, config), result|
        catch :skip_field do
          final_key, final_value = render_field(record, key, config)
          result[final_key] = final_value
        end
      end

      attributes.merge(merged_attributes.map do |key, value|
        [ transform_key(key), value ]
      end.to_h)
    end

    def render_field(record, key, config)
      if_condition = config[:if]
      throw :skip_field if if_condition && !instance_exec(record, &Dalambda[if_condition])

      unless_condition = config[:unless]
      throw :skip_field if unless_condition && instance_exec(record, &Dalambda[unless_condition])

      aliased_key = config[:as] || key
      transformed_key = transform_key(aliased_key)

      rendered_value =
        case config[:type]
        when :field
          field_name = config[:value]
          if record.respond_to?(field_name)
            record.public_send(field_name)
          else
            raise FieldMissing.new(field_name, record)
          end
        when :computed
          instance_exec(record, context, &Dalambda[config[:value]])
        when :association
          resolve_association(record, key, config)
        else
          raise InvalidFieldType.new(key, config[:type])
        end

      if (refinement = config[:refine])
        rendered_value = instance_exec(rendered_value, &Dalambda[refinement])
      end

      [ transformed_key, rendered_value ]
    end

    def transform_key(key)
      transform = ActionSchema.configuration.transform_keys
      transform ? transform.call(key) : key
    end

    def resolve_association(record, key, config)
      association_schema = resolve_schema(config[:value])
      child_context = context.merge(config[:context] || {})
      if record.respond_to?(key)
        association_data = record.public_send(key)
      else
        raise FieldMissing.new(key, record)
      end
      return if association_data.nil?
      association_schema.new(association_data, context: child_context).render
    end

    def resolve_schema(value)
      case value
      when Symbol
        tagged_schema = self.class.tagged_schemas[value]
        raise SchemaNotFound.new(value) unless tagged_schema
        tagged_schema
      when Class
        value
      when Proc
        Class.new(ActionSchema::Base, &Dalambda[value]).tap do |schema_class|
          schema_class.tagged_schemas = tagged_schemas.dup
        end
      else
        raise InvalidSchemaValue.new(value)
      end
    end

    def apply_hooks(hook_name, data)
      self.class.hooks[hook_name].each do |hook|
        @transformed = nil
        instance_exec(data, &Dalambda[hook])
        data = @transformed || data
      end
      data
    end

    def transform(new_data)
      @transformed = new_data
    end
  end
end
