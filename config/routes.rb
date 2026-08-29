Rails.application.routes.draw do
  devise_for :users,
    skip: [ :registrations ],
    defaults: { format: :json },
    controllers: {
      sessions: "users/sessions",
      passwords: "users/devise_passwords"
    }

  namespace :users do
    put :change_password, to: "passwords#update"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  get "auth/me", to: "auth#me", defaults: { format: :json }

  namespace :clients do
    get :dashboard, to: "dashboard#index"
    resources :patient_notes, only: %i[index create update destroy]
    resources :sessions, only: %i[index]
  end

  namespace :therapists do
    get :dashboard, to: "dashboard#index"

    resources :patients, only: %i[index show create update destroy] do
      member do
        put :update_schedule
      end

      resources :notes,
                only: %i[index create show update destroy],
                controller: "clinical_notes",
                as: :clinical_notes

      resources :recurring_schedules, only: %i[index show create update destroy],
                param: :id
    end

    resources :sessions, only: %i[create update destroy]

    resources :calendar_blocks, only: %i[index show create update destroy]

    resource :transcription, only: %i[create]
  end
end
