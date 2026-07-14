require 'rails_helper'

RSpec.describe "Users::Sessions (Login / Logout)", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let!(:user)     { create(:user, :client, email: "test@example.com", password: "Password@123", therapist: therapist) }

  # POST /users/sign_in
  describe "POST /users/sign_in" do
    context "com credenciais válidas (cliente)" do
      before do
        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json
      end

      it "retorna 200" do
        expect(response).to have_http_status(:ok)
      end

      it "define o cookie auth_token na resposta" do
        expect(response.cookies["auth_token"]).to be_present
      end

      it "define o cookie auth_token como HttpOnly" do
        expect(response.headers["Set-Cookie"]).to match(/httponly/i)
      end

      it "define o cookie com SameSite=Lax no ambiente de teste (não-produção)" do
        expect(response.headers["Set-Cookie"]).to match(/SameSite=Lax/i)
      end

      it "define o cookie com Max-Age correspondente ao TTL do JWT" do
        expect(response.headers["Set-Cookie"]).to match(/max-age=\d+/i)
      end

      it "NÃO expõe o JWT no header Authorization da resposta" do
        expect(response.headers["Authorization"]).to be_nil
      end

      it "retorna csrf_token no corpo da resposta" do
        expect(json_body["csrf_token"]).to be_present
      end

      it "retorna csrf_token como string hexadecimal de 64 caracteres (HMAC-SHA256)" do
        expect(json_body["csrf_token"]).to match(/\A[0-9a-f]{64}\z/)
      end

      it "retorna o id do usuário" do
        expect(json_body["user"]["id"]).to eq(user.id)
      end

      it "retorna o email do usuário" do
        expect(json_body["user"]["email"]).to eq(user.email)
      end

      it "retorna o nome do usuário" do
        expect(json_body["user"]["name"]).to eq(user.name)
      end

      it "retorna a role do usuário" do
        expect(json_body["user"]["role"]).to eq("client")
      end

      it "retorna must_change_password: false por padrão" do
        expect(json_body["user"]["must_change_password"]).to be false
      end
    end

    context "com credenciais válidas (terapeuta)" do
      let(:therapist) { create(:user, :therapist, password: "Password@123") }

      before do
        post user_session_path,
             params: { user: { email: therapist.email, password: "Password@123" } },
             as: :json
      end

      it "retorna 200" do
        expect(response).to have_http_status(:ok)
      end

      it "retorna role: therapist" do
        expect(json_body["user"]["role"]).to eq("therapist")
      end

      it "retorna must_change_password: false por padrão" do
        expect(json_body["user"]["must_change_password"]).to be false
      end
    end

    context "quando must_change_password está ativo" do
      it "retorna must_change_password: true no corpo" do
        user.update!(must_change_password: true)

        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json

        expect(json_body["user"]["must_change_password"]).to be true
      end
    end

    context "acesso subsequente via cookie" do
      it "permite acessar endpoint protegido usando apenas o cookie (sem Authorization header)" do
        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json

        csrf = json_body["csrf_token"]

        get clients_dashboard_path, headers: { "X-CSRF-Token" => csrf }
        expect(response).to have_http_status(:ok)
      end

      it "rejeita acesso sem cookie mesmo com Authorization header forjado" do
        get clients_dashboard_path,
            headers: { "Authorization" => "Bearer token.invalido.qualquer" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "com dois logins consecutivos" do
      it "gera csrf_tokens diferentes (cada JWT tem JTI único)" do
        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json
        first_token = json_body["csrf_token"]

        post user_session_path,
             params: { user: { email: user.email, password: "Password@123" } },
             as: :json
        second_token = json_body["csrf_token"]

        expect(first_token).not_to eq(second_token)
      end
    end

    context "com email incorreto" do
      before do
        post user_session_path,
             params: { user: { email: "naoexiste@example.com", password: "Password@123" } },
             as: :json
      end

      it "retorna 401" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "não define cookie auth_token" do
        expect(response.cookies["auth_token"]).to be_blank
      end
    end

    context "com senha incorreta" do
      before do
        post user_session_path,
             params: { user: { email: user.email, password: "SenhaErrada" } },
             as: :json
      end

      it "retorna 401" do
        expect(response).to have_http_status(:unauthorized)
      end

      it "não define cookie auth_token" do
        expect(response.cookies["auth_token"]).to be_blank
      end

      it "não retorna csrf_token" do
        expect(json_body["csrf_token"]).to be_nil
      end
    end

    context "sem parâmetros" do
      it "retorna 401" do
        post user_session_path, params: {}, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "rate limiting" do
      it "retorna 429 após 5 tentativas falhas consecutivas (6ª requisição bloqueada)" do
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

  # DELETE /users/sign_out
  describe "DELETE /users/sign_out" do
    context "com cookie e CSRF token válidos" do
      let(:auth_headers) { auth_headers_for(user) }

      it "retorna 204 No Content" do
        delete destroy_user_session_path, headers: auth_headers
        expect(response).to have_http_status(:no_content)
      end

      it "limpa o cookie auth_token na resposta" do
        delete destroy_user_session_path, headers: auth_headers
        expect(response.cookies["auth_token"]).to be_blank
      end

      it "revoga o JWT — cookie não autentica após o logout" do
        delete destroy_user_session_path, headers: auth_headers

        get clients_dashboard_path
        expect(response).to have_http_status(:unauthorized)
      end

      it "adiciona o JTI à denylist" do
        expect { delete destroy_user_session_path, headers: auth_headers }
          .to change(JwtDenylist, :count).by(1)
      end
    end

    context "com cookie válido mas sem X-CSRF-Token" do
      before { auth_headers_for(user) }

      it "retorna 403 (CSRF bloqueado)" do
        delete destroy_user_session_path
        expect(response).to have_http_status(:forbidden)
        expect(json_body["error"]).to match(/CSRF/)
      end
    end

    context "com cookie válido mas X-CSRF-Token incorreto" do
      before { auth_headers_for(user) }

      it "retorna 403" do
        delete destroy_user_session_path,
               headers: { "X-CSRF-Token" => "token_totalmente_invalido" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "sem cookie (não autenticado)" do
      it "não retorna 403 (CSRF não é validado sem cookie)" do
        delete destroy_user_session_path, as: :json
        expect(response).not_to have_http_status(:forbidden)
      end

      it "retorna 401" do
        delete destroy_user_session_path, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
