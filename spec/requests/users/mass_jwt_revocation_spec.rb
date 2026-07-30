require 'rails_helper'

RSpec.describe "Revogação em massa de JWT", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:password)  { "Password@123" }
  let!(:client) do
    create(:user, :client, password: password, therapist: therapist)
  end

  def open_second_session(user)
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post "/users/sign_in",
                 params: { user: { email: user.email, password: password } }.to_json,
                 headers: { "Content-Type" => "application/json" }

    raise "login da segunda sessão falhou: #{session.response.status}" unless session.response.status == 200

    [ session, JSON.parse(session.response.body)["csrf_token"] ]
  end

  describe "troca de senha autenticada" do
    let!(:victim_headers) { auth_headers(client) }

    it "invalida o token da outra sessão" do
      attacker, attacker_csrf = open_second_session(client)

      put users_change_password_path,
          params: { current_password: password, password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
          headers: victim_headers,
          as: :json
      expect(response).to have_http_status(:ok)

      attacker.get "/clients/dashboard", headers: { "X-CSRF-Token" => attacker_csrf }
      expect(attacker.response.status).to eq(401)
    end

    it "incrementa token_version" do
      expect {
        put users_change_password_path,
            params: { current_password: password, password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
            headers: victim_headers,
            as: :json
      }.to change { client.reload.token_version }.by(1)
    end

    it "invalida também o token de quem trocou a senha" do
      put users_change_password_path,
          params: { current_password: password, password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
          headers: victim_headers,
          as: :json

      get clients_dashboard_path, headers: victim_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "permite login com a nova senha depois da revogação" do
      put users_change_password_path,
          params: { current_password: password, password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
          headers: victim_headers,
          as: :json

      post user_session_path,
           params: { user: { email: client.email, password: "NovaSenha@456" } },
           as: :json

      expect(response).to have_http_status(:ok)
    end

    it "não incrementa token_version quando a troca falha" do
      expect {
        put users_change_password_path,
            params: { current_password: "senha-errada", password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
            headers: victim_headers,
            as: :json
      }.not_to change { client.reload.token_version }
    end
  end

  describe "reset de senha por e-mail" do
    it "invalida os tokens já emitidos" do
      attacker, attacker_csrf = open_second_session(client)
      raw_token = client.send_reset_password_instructions

      put user_password_path,
          params: { user: { reset_password_token: raw_token, password: "OutraSenha@789", password_confirmation: "OutraSenha@789" } },
          as: :json
      expect(response).to have_http_status(:ok)

      attacker.get "/clients/dashboard", headers: { "X-CSRF-Token" => attacker_csrf }
      expect(attacker.response.status).to eq(401)
    end

    it "incrementa token_version" do
      raw_token = client.send_reset_password_instructions

      expect {
        put user_password_path,
            params: { user: { reset_password_token: raw_token, password: "OutraSenha@789", password_confirmation: "OutraSenha@789" } },
            as: :json
      }.to change { client.reload.token_version }.by(1)
    end

    it "não incrementa token_version com token de reset inválido" do
      expect {
        put user_password_path,
            params: { user: { reset_password_token: "token-invalido", password: "OutraSenha@789", password_confirmation: "OutraSenha@789" } },
            as: :json
      }.not_to change { client.reload.token_version }
    end
  end

  describe "desativação da conta" do
    it "incrementa token_version além de bloquear a autenticação" do
      expect { client.update!(active: false) }
        .to change { client.reload.token_version }.by(1)
    end

    it "não incrementa quando a conta é reativada" do
      client.update!(active: false)

      expect { client.update!(active: true) }
        .not_to change { client.reload.token_version }
    end
  end

  describe "logout (revogação de um token só)" do
    it "não derruba a outra sessão do mesmo usuário" do
      other, other_csrf = open_second_session(client)
      headers = auth_headers(client)

      delete destroy_user_session_path, headers: headers
      expect(response).to have_http_status(:no_content)

      other.get "/clients/dashboard", headers: { "X-CSRF-Token" => other_csrf }
      expect(other.response.status).to eq(200)
    end

    it "não incrementa token_version" do
      headers = auth_headers(client)

      expect { delete destroy_user_session_path, headers: headers }
        .not_to change { client.reload.token_version }
    end
  end

  describe "claim de versão no token emitido" do
    it "embute token_version no payload do JWT" do
      client.update_column(:token_version, 7)
      auth_headers(client)

      token   = cookies["auth_token"]
      payload = JWT.decode(token, nil, false).first

      expect(payload[JwtRevocation::VERSION_CLAIM]).to eq(7)
    end
  end
end
