require "spec_helper"

RSpec.describe ActionSchema::Controller do
  helper :define_controller do |parent: Object, &block|
    Class.new(parent) do
      include ActionSchema::Controller
      class_eval(&block) if block
    end
  end

  describe ".schema" do
    it "defines a schema for the controller" do
      controller_class = define_controller do
        schema :default do
          field :name
        end
      end
      schema_class = controller_class.tagged_schemas[:default]
      expect(schema_class).to be < ActionSchema::Base
      expect(schema_class.schema).to eq({
        name: { type: :field, value: :name }
      })
    end

    it "inherits schemas from the superclass" do
      parent_controller = define_controller do
        schema :default do
          field :name
        end
      end
      child_controller = define_controller(parent: parent_controller)
      child_schema = child_controller.tagged_schemas[:default]
      expect(child_schema).to be < ActionSchema::Base
    end

    it "sets the schema name to :default if none is provided" do
      controller_class = define_controller do
        schema do
          field :name
        end
      end
      controller_schema = controller_class.tagged_schemas[:default]
      expect(controller_schema).to be < ActionSchema::Base
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
      expect(controller_class.tagged_schemas.keys).to eq([ :default, :other ])
    end

    it "provides context to the schema" do
      controller_class = define_controller do
        schema_context(foo: "bar")
        schema :default do
          field :name
        end
      end
      schema_class = controller_class.tagged_schemas[:default]
      expect(schema_class.context).to eq(foo: "bar")
    end

    it "provides tagged schemas to the schema" do
      controller_class = define_controller do
        schema :default do
          field :name
        end
      end
      schema_class = controller_class.tagged_schemas[:default]
      expect(schema_class.tagged_schemas).to eq(controller_class.tagged_schemas)
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

  describe "#schema_for" do
    it "instantiates a controller schema" do
      controller_class = define_controller do
        schema do
          field :name
        end
      end
      controller = controller_class.new
      schema = controller.schema_for(:default)
      expect(schema).to be_a(ActionSchema::Base)
    end

    it "passes the renderable to the schema" do
      controller_class = define_controller do
        schema do
          field :name
        end
      end
      controller = controller_class.new
      record = double(name: "Alice")
      schema = controller.schema_for(:default, with: record)
      expect(schema.renderable).to eq(record)
    end

    it "passes context to the schema" do
      controller_class = define_controller do
        schema do
          field :name
        end
      end
      controller = controller_class.new
      schema = controller.schema_for(:default, context: { foo: "bar" })
      expect(schema.context).to eq(foo: "bar")
    end

    it "raises an error if the schema is not defined" do
      controller_class = define_controller
      controller = controller_class.new
      record = double(name: "Alice")
      expect { controller.schema_for(:default) }.to raise_error(ArgumentError)
    end
  end

  describe '#schema' do
    it "instantiates an inline schema" do
      controller_class = define_controller
      controller = controller_class.new
      schema = controller.schema do
        field :name
      end
      expect(schema).to be_a(ActionSchema::Base)
      expect(schema.class.schema).to eq({
        name: { type: :field, value: :name }
      })
    end
  end

  describe "#action_schema" do
    it "instantiates a schema for the action" do
      controller_class = define_controller do
        schema :show do
          field :name
        end

        def show
          action_schema
        end

        private

        # This is a Rails method that we need to stub out
        def action_name
          "show"
        end
      end
      controller = controller_class.new
      schema = controller.show
      expect(schema).to be_a(ActionSchema::Base)
    end
  end
end
