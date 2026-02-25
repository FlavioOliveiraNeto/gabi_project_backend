require 'rails_helper'

RSpec.describe "Users::Passwords (Troca de Senha)", type: :request do
  let!(:user) { create(:user, :client) }
  let(:auth_headers) { auth_headers_for(user) }

  # ─── Troca de senha pós-login ──────────────────────────────────────────────
  describe "PUT /users/change_password" do
    context "com dados válidos" do
      let(:valid_params) do
        { password: "NovaSenha@456", password_confirmation: "NovaSenha@456" }
      end

      it "retorna 200 com sucesso" do
        put users_change_password_path,
            params: valid_params,
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:ok)
        expect(json_body["success"]).to be true
      end

      it "atualiza a senha no banco" do
        put users_change_password_path,
            params: valid_params,
            headers: auth_headers,
            as: :json

        user.reload
        expect(user.valid_password?("NovaSenha@456")).to be true
      end

      it "limpa a flag must_change_password" do
        user.update!(must_change_password: true)

        put users_change_password_path,
            params: valid_params,
            headers: auth_headers,
            as: :json

        expect(user.reload.must_change_password).to be false
      end

      it "revoga o JWT atual — token antigo retorna 401" do
        old_headers = auth_headers_for(user)

        put users_change_password_path,
            params: valid_params,
            headers: old_headers,
            as: :json

        expect(response).to have_http_status(:ok)

        # Token antigo deve estar na denylist
        get clients_dashboard_path, headers: old_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "com senhas que não coincidem" do
      it "retorna 422" do
        put users_change_password_path,
            params: { password: "NovaSenha@456", password_confirmation: "Diferente@999" },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["error"]).to match(/não coincidem/)
      end
    end

    context "com campos em branco" do
      it "retorna 422 quando password está em branco" do
        put users_change_password_path,
            params: { password: "", password_confirmation: "" },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["error"]).to match(/obrigatórias/)
      end
    end

    context "sem autenticação" do
      it "retorna 401" do
        put users_change_password_path,
            params: { password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── Reset de senha (Devise — via e-mail) ──────────────────────────────────
  describe "POST /users/password (solicitar reset)" do
    let!(:target_user) { create(:user, :client, email: "reset@example.com") }

    it "retorna 200 com mensagem genérica (sem revelar se o email existe)" do
      post user_password_path,
           params: { user: { email: "reset@example.com" } },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body["message"]).to be_present
    end

    it "retorna 200 mesmo para email inexistente (anti-enumeração)" do
      post user_password_path,
           params: { user: { email: "naoexiste@example.com" } },
           as: :json

      # Devise retorna ok para não revelar existência do email
      expect(response).to have_http_status(:ok)
    end

    context "rate limiting" do
      it "retorna 429 após 5 tentativas em 5 minutos" do
        6.times do
          post user_password_path,
               params: { user: { email: "reset@example.com" } },
               as: :json
        end

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end
end
