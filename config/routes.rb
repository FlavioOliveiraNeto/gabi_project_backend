Rails.application.routes.draw do
  devise_for :users,
    defaults: { format: :json },
    controllers: {
      sessions: "users/sessions"
    }
  get "up" => "rails/health#show", as: :rails_health_check

  # Dashboard do cliente (Paciente)
  namespace :clients do
    get :dashboard, to: "dashboard#index"
  end

  # Dashboard do admin (Terapeuta)
  namespace :admins do
    get :dashboard, to: "dashboard#index"
  end
end
