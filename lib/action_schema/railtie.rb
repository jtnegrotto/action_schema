module ActionSchema
  class Railtie < ::Rails::Railtie
    initializer "action_schema.controller" do
      Rails.logger.debug("ActionSchema Railtie loaded")

      ActiveSupport.on_load(:action_controller_base) do
        Rails.logger.debug("Including ActionSchema::Controller into ActionController::Base")
        include ActionSchema::Controller
      end
    end
  end
end
