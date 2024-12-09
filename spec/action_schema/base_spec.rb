require "spec_helper"

RSpec.describe ActionSchema::Base do
  def define_schema(base_class = described_class, &block)
    Class.new(base_class, &block)
  end

  def create_record(**attributes, &block)
    OpenStruct.new(attributes, &block)
  end

  describe "rendering" do
    it "renders a record" do
      schema = define_schema { fields :id, :name }
      record = create_record(id: 1, name: "John McClane")
      rendered = schema.call(record)
      expect(rendered).to eq(id: 1, name: "John McClane")
    end

    describe "fields" do
      it "renders only the specified fields" do
        schema = define_schema { fields :id, :name }
        record = create_record(id: 1, name: "John McClane", age: 50)
        rendered = schema.call(record)
        expect(rendered).to eq(id: 1, name: "John McClane")
      end

      it "excludes omitted fields" do
        schema = define_schema {
          fields :id, :name, :age
          omit :age
        }
        record = create_record(id: 1, name: "John McClane", age: 50)
        rendered = schema.call(record)
        expect(rendered).to eq(id: 1, name: "John McClane")
      end

      it "supports computed fields with blocks" do
        schema = define_schema {
          computed(:name) { |record| [ record.first_name, record.last_name ].join(" ") }
        }
        record = create_record(first_name: "John", last_name: "McClane")
        rendered = schema.call(record)
        expect(rendered).to eq(name: "John McClane")
      end

      it "supports computed fields with lambdas" do
        schema = define_schema {
          computed :name, ->(record) { [ record.first_name, record.last_name ].join(" ") }
        }
        record = create_record(first_name: "John", last_name: "McClane")
        rendered = schema.call(record)
        expect(rendered).to eq(name: "John McClane")
      end

      context "with if condition" do
        it "includes fields if the condition evaluates to true" do
          schema = define_schema {
            field :name, if: ->(record) { record.name.present? }
          }
          record = create_record(name: "John McClane")
          rendered = schema.call(record)
          expect(rendered).to eq(name: "John McClane")
        end

        it "excludes fields if the condition evaluates to false" do
          schema = define_schema {
            field :name, if: ->(record) { record.name.present? }
          }
          record = create_record(name: nil)
          rendered = schema.call(record)
          expect(rendered).to eq({})
        end
      end

      context "with unless condition" do
        it "includes fields if the condition evaluates to false" do
          schema = define_schema {
            field :name, unless: ->(record) { record.name.blank? }
          }
          record = create_record(name: "John McClane")
          rendered = schema.call(record)
          expect(rendered).to eq(name: "John McClane")
        end

        it "excludes fields if the condition evaluates to true" do
          schema = define_schema {
            field :name, unless: ->(record) { record.name.blank? }
          }
          record = create_record(name: nil)
          rendered = schema.call(record)
          expect(rendered).to eq({})
        end
      end

      it "returns an empty hash if no fields are defined" do
        schema = define_schema
        record = create_record(id: 1, name: "John McClane")
        rendered = schema.call(record)
        expect(rendered).to eq({})
      end

      it "raises an error if a field does not exist on the record" do
        schema = define_schema { fields :id, :name }
        record = create_record(id: 1)
        expect { schema.call(record) }.to raise_error(ActionSchema::FieldError)
      end

      context 'with inherited fields' do
        let(:base_schema) { define_schema { fields :id } }

        it 'includes inherited fields' do
          schema = define_schema(base_schema) { fields :name }
          record = create_record(id: 1, name: "John McClane")
          rendered = schema.call(record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        it 'excludes omitted inherited fields' do
          schema = define_schema(base_schema) {
            fields :name
            omit :id
          }
          record = create_record(id: 1, name: "John McClane")
          rendered = schema.call(record)
          expect(rendered).to eq(name: "John McClane")
        end
      end
    end

    describe "associations" do
      it "renders nested schemas" do
        post_schema = define_schema { fields :id, :title }
        schema = define_schema {
          fields :id, :name
          association :posts, post_schema
        }
        posts = [
          create_record(id: 1, title: "Post 1"),
          create_record(id: 2, title: "Post 2")
        ]
        record = create_record(id: 1, name: "John McClane", posts: posts)
        rendered = schema.call(record)
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
        schema = define_schema {
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
        rendered = schema.call(record)
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
        schema = define_schema {
          fields :id, :name
          association :posts, -> {
            fields :id, :title
          }
        }
        posts = [
          create_record(id: 1, title: "Post 1"),
          create_record(id: 2, title: "Post 2")
        ]
        record = create_record(id: 1, name: "John McClane", posts: posts)
        rendered = schema.call(record)
        expect(rendered).to eq(
          id: 1,
          name: "John McClane",
          posts: [
            { id: 1, title: "Post 1" },
            { id: 2, title: "Post 2" }
          ],
        )
      end

      it "raises an error if no schema is provided" do
        expect {
          schema = define_schema {
            fields :id, :name
            association :posts
          }
        }.to raise_error(ArgumentError)
      end

      it "handles nil associations" do
        schema = define_schema {
          fields :id, :name
          association :favorite_post do
            fields :id, :title
          end
        }
        record = create_record(id: 1, name: "John McClane", favorite_post: nil)
        rendered = schema.call(record)
        expect(rendered).to eq(id: 1, name: "John McClane", favorite_post: nil)
      end

      it "handles empty associations" do
        schema = define_schema {
          fields :id, :name
          association :posts do
            fields :id, :title
          end
        }
        record = create_record(id: 1, name: "John McClane", posts: [])
        rendered = schema.call(record)
        expect(rendered).to eq(id: 1, name: "John McClane", posts: [])
      end
    end

    describe "hooks" do
      describe "before_render" do
        it "runs before rendering the record or collection" do
          schema = define_schema {
            fields :id, :name
            before_render { |record| record.name = "John McClane" }
          }
          record = create_record(id: 1)
          rendered = schema.call(record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        it "does not replace the record" do
          schema = define_schema {
            fields :id, :name
            before_render do |record|
              record.clone.tap { |r| r.name = "John McClane" }
            end
          }
          record = create_record(id: 1, name: "Hans Gruber")
          rendered = schema.call(record)
          expect(record.name).to eq("Hans Gruber")
        end

        it "accepts the hook as a lambda" do
          schema = define_schema {
            fields :id, :name
            before_render ->(record) { record.name = "John McClane" }
          }
          record = create_record(id: 1)
          rendered = schema.call(record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        context "with transformation" do
          it "replaces the record with the transformed value" do
            schema = define_schema {
              fields :id, :name
              before_render do |record|
                transform(record.clone.tap { |r| r.name = "John McClane" })
              end
            }
            record = create_record(id: 1, name: "Hans Gruber")
            rendered = schema.call(record)
            expect(rendered[:name]).to eq("John McClane")
          end
        end
      end

      describe "after_render" do
        it "runs after rendering the record or collection" do
          schema = define_schema {
            fields :id
            after_render { |output| output[:name] = "John McClane" }
          }
          record = create_record(id: 1)
          rendered = schema.call(record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        it "does not replace the output" do
          schema = define_schema {
            fields :id
            after_render { |output| output.clone.tap { |o| o[:name] = "John McClane" } }
          }
          record = create_record(id: 1)
          rendered = schema.call(record)
          expect(rendered).to_not have_key(:name)
        end

        it "accepts the hook as a lambda" do
          schema = define_schema {
            fields :id
            after_render ->(output) { output[:name] = "John McClane" }
          }
          record = create_record(id: 1)
          rendered = schema.call(record)
          expect(rendered).to eq(id: 1, name: "John McClane")
        end

        context "with transformation" do
          it "replaces the output with the transformed value" do
            schema = define_schema {
              fields :id
              after_render { |output| transform(output.clone.tap { |o| o[:name] = "John McClane" }) }
            }
            record = create_record(id: 1)
            rendered = schema.call(record)
            expect(rendered[:name]).to eq("John McClane")
          end
        end
      end
    end

    describe "controller schema resolution" do
      it "resolves Symbols to schemas defined in the associated controller" do
        controller_class = Class.new do
          include ActionSchema::Controller

          schema :post do
            fields :id, :title
          end
        end
        schema = define_schema {
          fields :id, :name
          association :posts, :post
        }
        post = create_record(id: 1, title: "Post 1")
        record = create_record(id: 1, name: "John McClane", posts: [ post ])
        rendered = schema.call(record, controller: controller_class.new)
        expect(rendered).to eq(
          id: 1,
          name: "John McClane",
          posts: [ { id: 1, title: "Post 1" } ],
        )
      end
    end

    it "applies configured key transformations" do
      original_transform_keys = ActionSchema.configuration.transform_keys

      begin
        ActionSchema.configuration.transform_keys = ->(key) { key.to_s.upcase }

        schema = define_schema { fields :id, :name }
        record = create_record(id: 1, name: "John McClane")
        rendered = schema.call(record)
        expect(rendered).to eq("ID" => 1, "NAME" => "John McClane")
      ensure
        ActionSchema.configuration.transform_keys = original_transform_keys
      end
    end
  end

  describe "parsing" do
    it "does not yet support parsing" do
      schema = define_schema
      expect { schema.parse({}) }.to raise_error(NotImplementedError)
    end
  end
end
