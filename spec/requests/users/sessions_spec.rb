require 'rails_helper'

RSpec.describe "Users::Sessions (Login / Logout)", type: :request do
  let!(:user) { create(:user, :client, email: "test@example.com", password: "Password@123") }

  # ─── Login ───────────────────────────────────────────────────────────────────
  describe "POST /users/sign_in" do
    context "com credenciais válidas" do
      it "retorna 200 com dados do usuário" do
        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json

        expect(response).to have_http_status(:ok)
      end

      it "inclui o token JWT no header Authorization" do
        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json

        expect(response.headers["Authorization"]).to be_present
        expect(response.headers["Authorization"]).to start_with("Bearer ")
      end

      it "retorna os dados básicos do usuário" do
        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json

        body = json_body
        expect(body["user"]["email"]).to eq(user.email)
        expect(body["user"]["name"]).to eq(user.name)
        expect(body["user"]["role"]).to eq("client")
        expect(body["user"]["id"]).to eq(user.id)
      end

      it "informa se o usuário precisa trocar a senha" do
        user.update!(must_change_password: true)

        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json

        expect(json_body["user"]["must_change_password"]).to be true
      end
    end

    context "com email incorreto" do
      it "retorna 401" do
        post user_session_path,
             params: { user: { email: "wrong@example.com", password: "Password@123" } },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "com senha incorreta" do
      it "retorna 401" do
        post user_session_path,
             params: { user: { email: user.email, password: "SenhaErrada" } },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "sem parâmetros" do
      it "retorna 401" do
        post user_session_path, params: {}, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "rate limiting" do
      it "retorna 429 após 5 tentativas consecutivas do mesmo IP" do
        6.times do
          post user_session_path,
               params: { user: { email: "brute@example.com", password: "errada" } },
               as: :json
        end

        expect(response).to have_http_status(:too_many_requests)
        expect(json_body["error"]).to match(/Muitas tentativas/)
      end
    end
  end

  # ─── Logout ──────────────────────────────────────────────────────────────────
  describe "DELETE /users/sign_out" do
    context "com token válido" do
      it "retorna 204 No Content" do
        headers = auth_headers_for(user)
        delete destroy_user_session_path, headers: headers

        expect(response).to have_http_status(:no_content)
      end

      it "invalida o token após o logout" do
        headers = auth_headers_for(user)
        delete destroy_user_session_path, headers: headers

        # Token revogado — não deve mais funcionar
        get clients_dashboard_path, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "sem token" do
      it "retorna 401" do
        delete destroy_user_session_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
