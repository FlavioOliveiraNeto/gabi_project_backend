Rails.application.routes.draw do
  devise_for :users
  get "up" => "rails/health#show", as: :rails_health_check
  root "home#index"

  namespace :admins do
    get :dashboard, to: "dashboard#index"
  end
end
