require "spec_helper"

RSpec.describe ActionSchema::Controller do
  def define_controller(&block)
    Class.new do
      include ActionSchema::Controller
      class_eval(&block) if block_given?
    end
  end

  describe ".schema" do
    it "defines a schema for the controller" do
      controller_class = define_controller do
        schema :default do
          field :name
        end
      end
      controller_schema = controller_class.action_schemas[:default].schema
      expect(controller_schema).to eq(name: { value: :name })
    end

    it "inherits schemas from the superclass" do
      parent_class = define_controller do
        schema :default do
          field :name
        end
      end
      child_class = Class.new(parent_class)
      child_schema = child_class.action_schemas[:default].schema
      expect(child_schema).to eq(name: { value: :name })
    end

    it "sets the schema name to :default if none is provided" do
      controller_class = define_controller do
        schema do
          field :name
        end
      end
      controller_schema = controller_class.action_schemas[:default].schema
      expect(controller_schema).to eq(name: { value: :name })
    end

    it "allows multiple schemas to be defined" do
      controller_class = define_controller do
        schema :default do
          field :name
        end
        schema :other do
          field :age
        end
      end
      expect(controller_class.action_schemas.keys).to eq([ :default, :other ])
    end
  end

  describe ".schema_context" do
    it "sets the default schema context for the controller" do
      controller_class = define_controller do
        schema_context foo: "bar"
      end
      expect(controller_class.default_schema_context).to eq(foo: "bar")
    end

    it "merges with previously set context" do
      controller_class = define_controller do
        schema_context foo: "bar"
        schema_context baz: "qux"
      end
      expect(controller_class.default_schema_context).to eq(foo: "bar", baz: "qux")
    end

    it "merges with context from the superclass" do
      parent_class = define_controller do
        schema_context foo: "bar"
      end
      child_class = Class.new(parent_class) do
        schema_context baz: "qux"
      end
      expect(child_class.default_schema_context).to eq(foo: "bar", baz: "qux")
    end
  end

  describe "#schema_context" do
    it "returns the resolved schema context for the controller" do
      controller_class = define_controller do
        schema_context foo: "bar"
      end
      controller = controller_class.new
      expect(controller.schema_context).to eq(foo: "bar")
    end

    it "evaluates proc values in the context" do
      controller_class = define_controller do
        schema_context foo: -> { "bar" }
      end
      controller = controller_class.new
      expect(controller.schema_context).to eq(foo: "bar")
    end
  end

  describe "#schema_for" do
    it "renders a record using an inline schema" do
      controller_class = define_controller
      controller = controller_class.new
      record = double(name: "Alice")
      schema = controller.schema_for(record) do
        field :name
      end
      expect(schema).to eq(name: "Alice")
    end

    it "renders a record using a named schema" do
      controller_class = define_controller do
        schema :default do
          field :name
        end
      end
      controller = controller_class.new
      record = double(name: "Alice")
      schema = controller.schema_for(record)
      expect(schema).to eq(name: "Alice")
    end

    it "renders a record using a schema class" do
      schema_class = Class.new(ActionSchema::Base) do
        field :name
      end
      controller_class = define_controller
      controller = controller_class.new
      record = double(name: "Alice")
      schema = controller.schema_for(record, schema_class)
      expect(schema).to eq(name: "Alice")
    end

    it "raises an error if the schema is not defined" do
      controller_class = define_controller
      controller = controller_class.new
      record = double(name: "Alice")
      expect {
        controller.schema_for(record)
      }.to raise_error(ArgumentError, "Schema `default` not defined")
    end
  end
end
