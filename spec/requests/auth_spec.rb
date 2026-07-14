require 'rails_helper'

RSpec.describe "GET /auth/me", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:client)    { create(:user, :client, therapist: therapist) }

  # Fluxo feliz - cliente
  context "autenticado como cliente" do
    before do
      auth_headers_for(client)
      get auth_me_path
    end

    it "retorna 200" do
      expect(response).to have_http_status(:ok)
    end

    it "inclui o id no payload" do
      expect(json_body["user"]["id"]).to eq(client.id)
    end

    it "inclui o email no payload" do
      expect(json_body["user"]["email"]).to eq(client.email)
    end

    it "inclui o nome no payload" do
      expect(json_body["user"]["name"]).to eq(client.name)
    end

    it "inclui role 'client'" do
      expect(json_body["user"]["role"]).to eq("client")
    end

    it "retorna must_change_password: false" do
      expect(json_body["user"]["must_change_password"]).to be false
    end

    it "inclui csrf_token no corpo" do
      expect(json_body["csrf_token"]).to be_present
    end

    it "csrf_token é string hexadecimal de 64 chars" do
      expect(json_body["csrf_token"]).to match(/\A[0-9a-f]{64}\z/)
    end
  end

  # Fluxo feliz - terapeuta
  context "autenticado como terapeuta" do
    before do
      auth_headers_for(therapist)
      get auth_me_path
    end

    it "retorna 200" do
      expect(response).to have_http_status(:ok)
    end

    it "inclui role 'therapist'" do
      expect(json_body["user"]["role"]).to eq("therapist")
    end

    it "inclui o id do terapeuta" do
      expect(json_body["user"]["id"]).to eq(therapist.id)
    end

    it "inclui o email do terapeuta" do
      expect(json_body["user"]["email"]).to eq(therapist.email)
    end

    it "inclui o nome do terapeuta" do
      expect(json_body["user"]["name"]).to eq(therapist.name)
    end

    it "retorna must_change_password: false para terapeuta" do
      expect(json_body["user"]["must_change_password"]).to be false
    end
  end

  # must_change_password
  context "quando must_change_password: true" do
    let(:client) { create(:user, :client, :must_change_password, therapist: therapist) }

    before do
      auth_headers_for(client)
      get auth_me_path
    end

    it "retorna 200 (endpoint acessível antes da troca de senha)" do
      expect(response).to have_http_status(:ok)
    end

    it "reflete must_change_password: true no payload" do
      expect(json_body["user"]["must_change_password"]).to be true
    end
  end

  # Determinismo do csrf_token por JTI
  context "determinismo do csrf_token por JTI" do
    before do
      post user_session_path,
           params: { user: { email: client.email, password: "Senha@123!" } },
           as: :json
      @login_csrf = json_body["csrf_token"]

      get auth_me_path
    end

    it "retorna o mesmo csrf_token que o login para a mesma sessão JWT" do
      expect(json_body["csrf_token"]).to eq(@login_csrf)
    end

    it "gera csrf_token diferente após logout e novo login (JTI rotacionado)" do
      first_csrf = @login_csrf

      delete destroy_user_session_path, headers: { "X-CSRF-Token" => first_csrf }

      post user_session_path,
           params: { user: { email: client.email, password: "Senha@123!" } },
           as: :json
      second_csrf = json_body["csrf_token"]

      expect(second_csrf).not_to eq(first_csrf)
    end
  end

  # Sem autenticação
  context "sem autenticação (sem cookie)" do
    it "retorna 401" do
      get auth_me_path
      expect(response).to have_http_status(:unauthorized)
    end

    it "não inclui user no corpo" do
      get auth_me_path
      expect(json_body["user"]).to be_nil
    end

    it "não inclui csrf_token no corpo" do
      get auth_me_path
      expect(json_body["csrf_token"]).to be_nil
    end
  end

  # JWT inválido
  context "com JWT inválido no cookie" do
    it "retorna 401 com assinatura forjada" do
      cookies["auth_token"] = "header.payload.invalidsignature"
      get auth_me_path
      expect(response).to have_http_status(:unauthorized)
    end

    it "retorna 401 com cookie malformado" do
      cookies["auth_token"] = "isso_nao_e_um_jwt"
      get auth_me_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # JWT revogado
  context "com JWT revogado" do
    it "retorna 401 após logout" do
      headers = auth_headers_for(client)
      delete destroy_user_session_path, headers: headers

      get auth_me_path
      expect(response).to have_http_status(:unauthorized)
    end

    it "retorna 401 após troca de senha" do
      headers = auth_headers_for(client)
      put users_change_password_path,
          params: { password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
          headers: headers,
          as: :json

      get auth_me_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # Isolamento de dados
  context "isolamento de dados" do
    it "retorna os dados do usuário autenticado, nunca de outro" do
      other_client = create(:user, :client, therapist: therapist)
      auth_headers_for(client)

      get auth_me_path

      expect(json_body["user"]["id"]).to eq(client.id)
      expect(json_body["user"]["id"]).not_to eq(other_client.id)
    end
  end
end
