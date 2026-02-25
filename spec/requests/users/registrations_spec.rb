require 'rails_helper'

RSpec.describe "Users::Registrations (Cadastro)", type: :request do
  # ─── Cadastro ────────────────────────────────────────────────────────────────
  describe "POST /users" do
    let(:valid_params) do
      {
        user: {
          name:                  "Novo Paciente",
          email:                 "novo@example.com",
          password:              "Password@123",
          password_confirmation: "Password@123"
        }
      }
    end

    context "com dados válidos" do
      it "cria o usuário com status 201" do
        expect {
          post user_registration_path, params: valid_params, as: :json
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it "retorna os dados do usuário criado" do
        post user_registration_path, params: valid_params, as: :json

        body = json_body
        expect(body["user"]["email"]).to eq("novo@example.com")
        expect(body["user"]["name"]).to eq("Novo Paciente")
        expect(body["user"]["role"]).to eq("client")
      end

      it "cria o usuário com role :client independentemente do que for passado" do
        post user_registration_path, params: valid_params, as: :json

        user = User.find_by(email: "novo@example.com")
        expect(user.client?).to be true
      end
    end

    context "auto-atribuição de terapeuta" do
      let!(:therapist) { create(:user, :therapist) }

      it "associa o primeiro terapeuta disponível ao novo cliente" do
        post user_registration_path, params: valid_params, as: :json

        user = User.find_by(email: "novo@example.com")
        expect(user.therapist).to eq(therapist)
      end

      context "quando há terapeuta no ENV THERAPIST_EMAIL" do
        let!(:preferred_therapist) do
          create(:user, :therapist, email: "gabi@clinica.com")
        end

        around do |example|
          original = ENV["THERAPIST_EMAIL"]
          ENV["THERAPIST_EMAIL"] = "gabi@clinica.com"
          example.run
          ENV["THERAPIST_EMAIL"] = original
        end

        it "associa ao terapeuta preferencial" do
          post user_registration_path, params: valid_params, as: :json

          user = User.find_by(email: "novo@example.com")
          expect(user.therapist).to eq(preferred_therapist)
        end
      end
    end

    context "com dados inválidos" do
      it "retorna 422 sem email" do
        params = valid_params.deep_merge(user: { email: "" })
        post user_registration_path, params: params, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end

      it "retorna 422 com senhas diferentes" do
        params = valid_params.deep_merge(user: { password_confirmation: "Diferente@456" })
        post user_registration_path, params: params, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "retorna 422 com email duplicado" do
        create(:user, email: "novo@example.com")
        post user_registration_path, params: valid_params, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "rate limiting" do
      it "retorna 429 após 5 tentativas consecutivas" do
        6.times do |i|
          post user_registration_path,
               params: { user: { name: "X", email: "x#{i}@x.com", password: "a", password_confirmation: "b" } },
               as: :json
        end

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end
end
