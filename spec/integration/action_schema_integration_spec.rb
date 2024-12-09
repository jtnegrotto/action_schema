require "spec_helper"

RSpec.describe "Action Schema Integration", type: :request do
  before do
    Rails.application.routes.draw do
      resources :users, only: [ :index ]
    end

    class UsersController < ActionController::Base
      schema do
        field :id
        computed(:name) { |user| [ user.first_name, user.last_name ].join(" ") }

        after_render do |data|
          transform({
            "users" => data,
            "meta" => {
              "total" => data.size
            }
          })
        end
      end

      def index
        users = [ OpenStruct.new(id: 1, first_name: "John", last_name: "McClane") ]
        render json: schema_for(users)
      end
    end
  end

  after do
    Rails.application.routes_reloader.reload!
  end

  it "renders the schema" do
    get "/users"
    expect(response).to have_http_status(:ok)
    expect(JSON(response.body)).to eq({
      "users" => [ { "id" => 1, "name" => "John McClane" } ],
      "meta" => { "total" => 1 }
    })
  end
end
