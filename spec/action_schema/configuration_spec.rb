require "spec_helper"

RSpec.describe ActionSchema::Configuration do
  describe 'ActionSchema.configuration' do
    it 'returns a Configuration instance' do
      expect(ActionSchema.configuration).to be_a(ActionSchema::Configuration)
    end

    describe '#base_class' do
      it 'returns ActionSchema::Base by default' do
        expect(ActionSchema.configuration.base_class).to eq(ActionSchema::Base)
      end

      it 'returns a custom base class if set' do
        custom_class = Class.new(ActionSchema::Base)
        ActionSchema.configuration.base_class = custom_class
        expect(ActionSchema.configuration.base_class).to eq(custom_class)
      end

      it 'constantizes a string base class' do
        ActionSchema.configuration.base_class = 'ActionSchema::Base'
        expect(ActionSchema.configuration.base_class).to eq(ActionSchema::Base)
      end
    end

    describe '#transform_keys' do
      it 'returns nil by default' do
        expect(ActionSchema.configuration.transform_keys).to be_nil
      end

      it 'returns a custom key transformer if set' do
        original_transformer = ActionSchema.configuration.transform_keys
        begin
          transformer = ->(key) { key.to_s.upcase }
          ActionSchema.configuration.transform_keys = transformer
          expect(ActionSchema.configuration.transform_keys).to eq(transformer)
        ensure
          ActionSchema.configuration.transform_keys = original_transformer
        end
      end
    end

    describe '#type_serializers' do
      it 'returns an empty hash by default' do
        expect(ActionSchema.configuration.type_serializers).to eq({})
      end

      it 'returns a hash of custom serializers if set' do
        serializers = { Date => ->(value) { value.to_s } }
        ActionSchema.configuration.type_serializers = serializers
        expect(ActionSchema.configuration.type_serializers).to eq(serializers)
      end
    end
  end

  describe 'ActionSchema.configure' do
    it 'yields the configuration instance' do
      ActionSchema.configure do |config|
        expect(config).to eq(ActionSchema.configuration)
      end
    end
  end
end
