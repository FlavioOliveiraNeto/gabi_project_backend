  put "/users/change_password", to: "users/passwords#update"
Rails.application.routes.draw do
  devise_for :users,
    defaults: { format: :json },
    controllers: {
      sessions: "users/sessions",
      registrations: "users/registrations"
    }

  get "up" => "rails/health#show", as: :rails_health_check

  # Dashboard e recursos do paciente
  namespace :clients do
    get :dashboard, to: "dashboard#index"
    resources :patient_notes, only: %i[index create destroy]
    resources :sessions, only: %i[index]
  end

  # Dashboard e recursos da terapeuta
  namespace :therapists do
    get :dashboard, to: "dashboard#index"
    resources :patients, only: %i[index show create update destroy] do
      resources :notes, only: %i[create], controller: "clinical_notes", as: :clinical_notes
    end
    resources :sessions, only: %i[create update]
  end
end
