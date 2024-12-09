require "spec_helper"

RSpec.describe ActionSchema::Railtie do
  it "includes ActionSchema::Controller in ActionController::Base" do
    expect(ActionController::Base.included_modules).to include(ActionSchema::Controller)
  end
end
