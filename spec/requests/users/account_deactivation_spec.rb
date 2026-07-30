require 'rails_helper'

RSpec.describe "Desativação de conta e autenticação", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:password)  { "Password@123" }
  let(:client) do
    create(:user, :client, password: password, therapist: therapist)
  end

  describe "POST /users/sign_in com conta desativada" do
    before do
      client.update!(active: false)

      post user_session_path,
           params: { user: { email: client.email, password: password } },
           as: :json
    end

    it "retorna 401" do
      expect(response).to have_http_status(:unauthorized)
    end

    it "não define o cookie auth_token" do
      expect(response.cookies["auth_token"]).to be_blank
    end

    it "não retorna csrf_token" do
      expect(json_body["csrf_token"]).to be_nil
    end

    it "informa que a conta está desativada" do
      expect(json_body["error"]).to eq(I18n.t("devise.failure.account_inactive"))
    end

    it "não revela se a senha estava correta" do
      post user_session_path,
           params: { user: { email: client.email, password: "senha-totalmente-errada" } },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "desativação com sessão JWT já emitida" do
    let!(:headers) { auth_headers(client) }

    it "permite acesso enquanto a conta está ativa" do
      get clients_dashboard_path, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "rejeita o token já emitido depois da desativação" do
      client.update!(active: false)

      get clients_dashboard_path, headers: headers

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejeita também endpoints de escrita depois da desativação" do
      client.update!(active: false)

      post clients_patient_notes_path,
           params: { content: "tentativa após desativação" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "não permite trocar a senha depois da desativação" do
      client.update!(active: false)

      put users_change_password_path,
          params: { current_password: password, password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "volta a autenticar se a conta for reativada" do
      client.update!(active: false)
      client.update!(active: true)

      get clients_dashboard_path, headers: auth_headers(client)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "terapeuta desativada" do
    let(:inactive_therapist) { create(:user, :therapist, password: password) }

    it "não autentica no login" do
      inactive_therapist.update!(active: false)

      post user_session_path,
           params: { user: { email: inactive_therapist.email, password: password } },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "perde o acesso ao dashboard com token já emitido" do
      headers = auth_headers(inactive_therapist)
      inactive_therapist.update!(active: false)

      get therapists_dashboard_path, headers: headers

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
