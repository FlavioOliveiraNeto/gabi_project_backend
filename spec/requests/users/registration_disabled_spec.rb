require 'rails_helper'

RSpec.describe "Auto-cadastro desabilitado", type: :request do
  let(:params) do
    {
      user: {
        name: "Invasor",
        email: "invasor@example.com",
        password: "Password@123",
        password_confirmation: "Password@123"
      }
    }
  end

  describe "POST /users" do
    it "não expõe a rota de cadastro" do
      post "/users", params: params, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "não cria nenhum usuário" do
      expect { post "/users", params: params, as: :json }
        .not_to change(User, :count)
    end
  end

  describe "rotas do Devise" do
    it "não registra a rota de cadastro" do
      expect(Rails.application.routes.routes.map(&:name)).not_to include("new_user_registration")
    end

    it "não define o módulo :registerable no User" do
      expect(User.devise_modules).not_to include(:registerable)
    end

    it "mantém as rotas de login e recuperação de senha" do
      expect(Rails.application.routes.routes.map(&:name))
        .to include("new_user_session", "user_password")
    end
  end

  describe "criação de paciente pela terapeuta" do
    let(:therapist) { create(:user, :therapist) }

    it "continua sendo o único caminho para criar um cliente" do
      expect {
        post therapists_patients_path,
             params: { name: "Paciente Legítima", email: "paciente@example.com" },
             headers: therapist_auth_headers(therapist),
             as: :json
      }.to change(User.clients, :count).by(1)

      expect(response).to have_http_status(:created)
    end
  end
end
