require "spec_helper"

RSpec.describe ActionSchema::Base do
  helper :create_schema do |base_class = described_class, &block|
    Class.new(base_class, &block)
  end

  helper :create_record do |**attributes, &block|
    OpenStruct.new(attributes, &block)
  end

  helper :render do |schema, record, context: {}|
    schema.render(record, context: context)
  end

  describe "definition" do
    matcher(:anything) { match { true } }

    matcher :define_schema do |expected_schema|
      match do |actual|
        expect(actual.schema).to match(expected_schema)
      end

      failure_message do |actual|
        <<~MESSAGE
          Expected schema:
          #{PP.pp(expected_schema, '')}

          Got schema:
          #{PP.pp(actual.schema, '')}

          Diff:
          #{RSpec::Support::Differ.new.diff(expected_schema, actual.schema)}
        MESSAGE
      end
    end
    alias_matcher :an_object_defining_schema, :define_schema

    matcher :a_proc_defining_schema do |expected_schema|
      match do |actual|
        schema = create_schema(&actual)
        expect(schema).to define_schema(expected_schema)
      end
    end

    matcher :define_schema_attribute do |expected_name, expected_spec|
      match do |actual|
        expect(actual.schema).to have_key(expected_name)
        expect(actual.schema[expected_name]).to match(expected_spec)
      end
    end

    it "defines a field" do
      schema = create_schema { field :id }
      expect(schema).to define_schema({ id: { type: :field, value: :id } })
    end

    it "defines multiple fields" do
      schema = create_schema { fields :id, :name }
      expect(schema).to define_schema({
        id: { type: :field, value: :id },
        name: { type: :field, value: :name }
      })
    end

    it "omits fields" do
      schema = create_schema { fields :id, :name, :age; omit :age }
      expect(schema).to_not define_schema_attribute(:age, anything)
    end

    it "defines a computed field" do
      compute = ->(record) { record.name.reverse }
      schema = create_schema { computed :name, compute }
      expect(schema).to define_schema({
        name: { type: :computed, value: compute }
      })
    end

    it "defines a schema with an association using a schema tag" do
      schema = create_schema { association :posts, :post_schema }
      expect(schema).to define_schema({
        posts: { type: :association, value: :post_schema }
      })
    end

    it "defines a schema with an association using a block" do
      schema = create_schema { association(:posts) { field :id } }
      expect(schema).to define_schema({
        posts: {
          type: :association,
          value: a_proc_defining_schema({
            id: { type: :field, value: :id }
          })
        }
      })
    end

    it "defines a schema with an association using a class" do
      other_schema = create_schema { field :id }
      schema = create_schema { association :posts, other_schema }
      expect(schema).to define_schema({
        posts: {
          type: :association,
          value: an_object_defining_schema({
            id: { type: :field, value: :id }
          })
        }
      })
    end
  end

  describe "rendering" do
    it "renders a record" do
      schema = create_schema { fields :id, :name }
      record = create_record(id: 1, name: "John McClane")
      rendered = render(schema, record)
      expect(rendered).to eq(id: 1, name: "John McClane")
    end

    describe "fields" do
      it "renders only the specified fields" do
        schema = create_schema { fields :id, :name }
        record = create_record(id: 1, name: "John McClane", age: 50)
        rendered = render(schema, record)
        expect(rendered).to eq(id: 1, name: "John McClane")
      end

      it "excludes omitted fields" do
        schema = create_schema {
          fields :id, :name, :age
          omit :age
        }
        record = create_record(id: 1, name: "John McClane", age: 50)
        rendered = render(schema, record)
        expect(rendered).to eq(id: 1, name: "John McClane")
      end

      it "supports computed fields with blocks" do
        schema = create_schema {
          computed(:name) { |record| [ record.first_name, record.last_name ].join(" ") }
        }
        record = create_record(first_name: "John", last_name: "McClane")
        rendered = render(schema, record)
        expect(rendered).to eq(name: "John McClane")
      end

      it "supports computed fields with lambdas" do
        schema = create_schema {
          computed :name, ->(record) { [ record.first_name, record.last_name ].join(" ") }
        }
        record = create_record(first_name: "John", last_name: "McClane")
        rendered = render(schema, record)
        expect(rendered).to eq(name: "John McClane")
      end

      it "supports renaming fields" do
        schema = create_schema {
          field :name, as: :full_name
        }
        record = create_record(name: "John McClane")
        rendered = render(schema, record)
        expect(rendered).to eq(full_name: "John McClane")
      end

      it "allows refining fields" do
        schema = create_schema {
          field :name, refine: ->(value) { value.upcase }
        }
        record = create_record(name: "John McClane")
        rendered = render(schema, record)
        expect(rendered).to eq(name: "JOHN MCCLANE")
      end

      context "with if condition" do
        it "includes fields if the condition evaluates to true" do
          schema = create_schema {
            field :name, if: ->(record) { record.name.present? }
          }
          record = create_record(name: "John McClane")
          rendered = render(schema, record)
          expect(rendered).to eq(name: "John McClane")
        end

        it "excludes fields if the condition evaluates to false" do
          schema = create_schema {
            field :name, if: ->(record) { record.name.present? }
          }
          record = create_record(name: nil)
          rendered = render(schema, record)
          expect(rendered).to eq({})
        end
      end

      context "with unless condition" do
        it "includes fields if the condition evaluates to false" do
          schema = create_schema {
            field :name, unless: ->(record) { record.name.blank? }
          }
          record = create_record(name: "John McClane")
          rendered = render(schema, record)
          expect(rendered).to eq(name: "John McClane")
        end

        it "excludes fields if the condition evaluates to true" do
          schema = create_schema {
            field :name, unless: ->(record) { record.name.blank? }
          }
          record = create_record(name: nil)
          rendered = render(schema, record)
          expect(rendered).to eq({})
        end
      end

      it "returns an empty hash if no fields are defined" do
        schema = create_schema
        record = create_record(id: 1, name: "John McClane")
        rendered = render(schema, record)
        expect(rendered).to eq({})
      end

      it "raises an error if a field does not exist on the record" do
        schema = create_schema { fields :id, :name }
        record = create_record(id: 1)
        expect { render(schema, record) }.to raise_error(ActionSchema::FieldMissing)
      end

      context 'with inherited fields' do
        let(:base_schema) { create_schema { fields :id } }

        it 'includes inherited fields' do
          schema = create_schema(base_schema) { fields :name }
          record = create_record(id: 1, name: "John McClane")
          rendered = render(schema, record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        it 'excludes omitted inherited fields' do
          schema = create_schema(base_schema) {
            fields :name
            omit :id
          }
          record = create_record(id: 1, name: "John McClane")
          rendered = render(schema, record)
          expect(rendered).to eq(name: "John McClane")
        end
      end
    end

    describe "associations" do
      it "renders nested schemas" do
        post_schema = create_schema { fields :id, :title }
        schema = create_schema {
          fields :id, :name
          association :posts, post_schema
        }
        posts = [
          create_record(id: 1, title: "Post 1"),
          create_record(id: 2, title: "Post 2")
        ]
        record = create_record(id: 1, name: "John McClane", posts: posts)
        rendered = render(schema, record)
        expect(rendered).to eq(
          id: 1,
          name: "John McClane",
          posts: [
            { id: 1, title: "Post 1" },
            { id: 2, title: "Post 2" }
          ],
        )
      end

      it "renders inline association schemas" do
        schema = create_schema {
          fields :id, :name
          association :posts do
            fields :id, :title
          end
        }
        posts = [
          create_record(id: 1, title: "Post 1"),
          create_record(id: 2, title: "Post 2")
        ]
        record = create_record(id: 1, name: "John McClane", posts: posts)
        rendered = render(schema, record)
        expect(rendered).to eq(
          id: 1,
          name: "John McClane",
          posts: [
            { id: 1, title: "Post 1" },
            { id: 2, title: "Post 2" }
          ],
        )
      end

      it "renders inline association schemas defined with lambdas" do
        schema = create_schema {
          fields :id, :name
          association :posts, &-> {
            fields :id, :title
          }
        }
        posts = [
          create_record(id: 1, title: "Post 1"),
          create_record(id: 2, title: "Post 2")
        ]
        record = create_record(id: 1, name: "John McClane", posts: posts)
        rendered = render(schema, record)
        expect(rendered).to eq(
          id: 1,
          name: "John McClane",
          posts: [
            { id: 1, title: "Post 1" },
            { id: 2, title: "Post 2" }
          ],
        )
      end

      it "supports renaming associations" do
        schema = create_schema do
          fields :id, :name
          association :posts, as: :articles do
            fields :id, :title
          end
        end
        posts = [
          create_record(id: 1, title: "Post 1"),
          create_record(id: 2, title: "Post 2")
        ]
        record = create_record(id: 1, name: "John McClane", posts: posts)
        rendered = render(schema, record)
        expect(rendered).to eq(
          id: 1,
          name: "John McClane",
          articles: [
            { id: 1, title: "Post 1" },
            { id: 2, title: "Post 2" }
          ],
        )
      end

      it "raises an error if no schema is provided" do
        expect {
          schema = create_schema {
            fields :id, :name
            association :posts
          }
        }.to raise_error(ArgumentError)
      end

      it "handles nil associations" do
        schema = create_schema {
          fields :id, :name
          association :favorite_post do
            fields :id, :title
          end
        }
        record = create_record(id: 1, name: "John McClane", favorite_post: nil)
        rendered = render(schema, record)
        expect(rendered).to eq(id: 1, name: "John McClane", favorite_post: nil)
      end

      it "handles empty associations" do
        schema = create_schema {
          fields :id, :name
          association :posts do
            fields :id, :title
          end
        }
        record = create_record(id: 1, name: "John McClane", posts: [])
        rendered = render(schema, record)
        expect(rendered).to eq(id: 1, name: "John McClane", posts: [])
      end
    end

    describe "hooks" do
      describe "before_render" do
        it "runs before rendering the record or collection" do
          schema = create_schema {
            fields :id, :name
            before_render { |record| record.name = "John McClane" }
          }
          record = create_record(id: 1)
          rendered = render(schema, record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        it "does not replace the record" do
          schema = create_schema {
            fields :id, :name
            before_render do |record|
              record.clone.tap { |r| r.name = "John McClane" }
            end
          }
          record = create_record(id: 1, name: "Hans Gruber")
          rendered = render(schema, record)
          expect(record.name).to eq("Hans Gruber")
        end

        it "accepts the hook as a lambda" do
          schema = create_schema {
            fields :id, :name
            before_render ->(record) { record.name = "John McClane" }
          }
          record = create_record(id: 1)
          rendered = render(schema, record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        context "with transformation" do
          it "replaces the record with the transformed value" do
            schema = create_schema {
              fields :id, :name
              before_render do |record|
                transform(record.clone.tap { |r| r.name = "John McClane" })
              end
            }
            record = create_record(id: 1, name: "Hans Gruber")
            rendered = render(schema, record)
            expect(rendered[:name]).to eq("John McClane")
          end
        end
      end

      describe "after_render" do
        it "runs after rendering the record or collection" do
          schema = create_schema {
            fields :id
            after_render { |output| output[:name] = "John McClane" }
          }
          record = create_record(id: 1)
          rendered = render(schema, record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        it "does not replace the output" do
          schema = create_schema {
            fields :id
            after_render { |output| output.clone.tap { |o| o[:name] = "John McClane" } }
          }
          record = create_record(id: 1)
          rendered = render(schema, record)
          expect(rendered).to_not have_key(:name)
        end

        it "accepts the hook as a lambda" do
          schema = create_schema {
            fields :id
            after_render ->(output) { output[:name] = "John McClane" }
          }
          record = create_record(id: 1)
          rendered = render(schema, record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        context "with transformation" do
          it "replaces the output with the transformed value" do
            schema = create_schema {
              fields :id
              after_render { |output| transform(output.clone.tap { |o| o[:name] = "John McClane" }) }
            }
            record = create_record(id: 1)
            rendered = render(schema, record)
            expect(rendered[:name]).to eq("John McClane")
          end
        end
      end
    end

    describe "tagged schema resolution" do
      it "resolves Symbols to tagged schemas" do
        post_schema = create_schema { fields :id, :title }
        schema = create_schema {
          fields :id, :name
          association :posts, :post
        }
        schema.tagged_schemas = { post: post_schema }
        post = create_record(id: 1, title: "Post 1")
        record = create_record(id: 1, name: "John McClane", posts: [ post ])
        rendered = render(schema, record)
        expect(rendered).to eq(
          id: 1,
          name: "John McClane",
          posts: [ { id: 1, title: "Post 1" } ],
        )
      end
    end

    it "merges extra attributes" do
      schema = create_schema { fields :id, :name }
      record = create_record(id: 1, name: "John McClane")
      renderer = schema.new(record)
      renderer.merge!(extra: "value")
      expect(renderer.render).to eq(id: 1, name: "John McClane", extra: "value")
    end

    it "applies configured key transformations" do
      original_transform_keys = ActionSchema.configuration.transform_keys

      begin
        ActionSchema.configuration.transform_keys = ->(key) { key.to_s.upcase }

        schema = create_schema { fields :id, :name }
        record = create_record(id: 1, name: "John McClane")
        rendered = render(schema, record)
        expect(rendered).to eq("ID" => 1, "NAME" => "John McClane")
      ensure
        ActionSchema.configuration.transform_keys = original_transform_keys
      end
    end
  end

  describe "parsing" do
    it "does not yet support parsing" do
      schema = create_schema
      expect { schema.parse({}) }.to raise_error(NotImplementedError)
    end
  end
end
