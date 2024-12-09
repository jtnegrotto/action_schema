module ActionSchema
  class Railtie < ::Rails::Railtie
    initializer "action_schema.controller" do
      ActiveSupport.on_load(:action_controller_base) do
        include ActionSchema::Controller
      end
    end
  end
end
