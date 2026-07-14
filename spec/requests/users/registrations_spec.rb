require 'rails_helper'

RSpec.describe "Users::Registrations", type: :request do
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

    #Fluxo feliz
    context "com dados válidos" do
      it "cria o usuário no banco" do
        expect {
          post user_registration_path, params: valid_params, as: :json
        }.to change(User, :count).by(1)
      end

      context "ao retornar a resposta" do
        before { post user_registration_path, params: valid_params, as: :json }

        it "retorna 201" do
          expect(response).to have_http_status(:created)
        end

        it "inclui id, name, email e role no body" do
          expect(json_body["user"]).to include(
            "id"    => be_present,
            "name"  => "Novo Paciente",
            "email" => "novo@example.com",
            "role"  => "client"
          )
        end

        it "força role :client independentemente do que for passado" do
          user = User.find_by(email: "novo@example.com")
          expect(user.client?).to be(true)
        end
      end
    end

    #phone permitido em sign_up_params
    context "com phone informado" do
      before do
        post user_registration_path,
             params: valid_params.deep_merge(user: { phone: "11999999999" }),
             as: :json
      end

      it "salva o phone no banco" do
        user = User.find_by(email: "novo@example.com")
        expect(user.phone).to eq("11999999999")
      end
    end

    #Auto-atribuição de terapeuta
    context "sem terapeuta cadastrado" do
      before { post user_registration_path, params: valid_params, as: :json }

      it "cria o usuário sem associar terapeuta" do
        user = User.find_by(email: "novo@example.com")
        expect(user.therapist).to be_nil
      end
    end

    context "com terapeuta disponível" do
      let!(:therapist) { create(:user, :therapist) }

      before { post user_registration_path, params: valid_params, as: :json }

      it "associa o primeiro terapeuta disponível ao novo cliente" do
        user = User.find_by(email: "novo@example.com")
        expect(user.therapist).to eq(therapist)
      end
    end

    context "quando THERAPIST_EMAIL está configurado" do
      let!(:other_therapist)     { create(:user, :therapist) }
      let!(:preferred_therapist) { create(:user, :therapist, email: "gabi@clinica.com") }

      around do |example|
        original = ENV["THERAPIST_EMAIL"]
        ENV["THERAPIST_EMAIL"] = "gabi@clinica.com"
        example.run
        ENV["THERAPIST_EMAIL"] = original
      end

      before { post user_registration_path, params: valid_params, as: :json }

      it "associa ao terapeuta preferencial ignorando outros disponíveis" do
        user = User.find_by(email: "novo@example.com")
        expect(user.therapist).to eq(preferred_therapist)
      end
    end

    #Dados inválidos
    context "com dados inválidos" do
      it "retorna 422 sem email" do
        post user_registration_path,
             params: valid_params.deep_merge(user: { email: "" }),
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to include(match(/[Ee]mail/))
      end

      it "retorna 422 com senhas divergentes" do
        post user_registration_path,
             params: valid_params.deep_merge(user: { password_confirmation: "Diferente@456" }),
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end

      it "retorna 422 com email duplicado" do
        create(:user, email: "novo@example.com")

        post user_registration_path, params: valid_params, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end
    end

    #Rate limiting
    context "rate limiting" do
      it "retorna 429 após exceder o limite de tentativas" do
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
