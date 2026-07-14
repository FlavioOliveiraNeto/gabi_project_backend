require "rails_helper"

RSpec.describe "CSRF Protection", type: :request do
  let(:therapist) { create(:user, :therapist) }
  let(:client)    { create(:user, :client, therapist: therapist) }

  # Métodos seguros (GET / HEAD) - never blocked by CSRF
  describe "métodos seguros (GET / HEAD) ignoram validação CSRF" do
    context "com cookie de sessão ativo mas sem X-CSRF-Token" do
      before { auth_headers_for(client) }

      it "GET /auth/me retorna 200 sem validar CSRF" do
        get auth_me_path
        expect(response).not_to have_http_status(:forbidden)
        expect(response).to have_http_status(:ok)
      end

      it "GET em endpoint de cliente retorna 200 sem validar CSRF" do
        get clients_dashboard_path
        expect(response).not_to have_http_status(:forbidden)
        expect(response).to have_http_status(:ok)
      end

      it "HEAD /auth/me retorna 200 sem validar CSRF" do
        head auth_me_path
        expect(response).not_to have_http_status(:forbidden)
        expect(response).to have_http_status(:ok)
      end
    end

    context "sem autenticação" do
      it "GET retorna 401, não 403" do
        get clients_dashboard_path
        expect(response).to have_http_status(:unauthorized)
        expect(response).not_to have_http_status(:forbidden)
      end
    end
  end

  # DELETE com cookie de sessão
  describe "DELETE com cookie de sessão" do
    let(:auth_headers) { auth_headers_for(client) }

    before { auth_headers }

    context "sem X-CSRF-Token" do
      it "retorna 403 com mensagem CSRF" do
        delete destroy_user_session_path
        expect(response).to have_http_status(:forbidden)
        expect(json_body["error"]).to match(/CSRF/)
      end
    end

    context "com X-CSRF-Token incorreto" do
      it "retorna 403" do
        delete destroy_user_session_path,
               headers: { "X-CSRF-Token" => "aaaa" * 16 }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "com X-CSRF-Token vazio" do
      it "retorna 403" do
        delete destroy_user_session_path,
               headers: { "X-CSRF-Token" => "" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "com X-CSRF-Token correto" do
      it "retorna 204" do
        delete destroy_user_session_path, headers: auth_headers
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  # PUT com cookie de sessão
  describe "PUT com cookie de sessão" do
    let(:auth_headers) { auth_headers_for(client) }

    before { auth_headers }

    context "sem X-CSRF-Token" do
      it "retorna 403" do
        put users_change_password_path,
            params: { password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
            as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "com X-CSRF-Token correto" do
      it "não retorna 403 (chega ao endpoint e processa a lógica)" do
        put users_change_password_path,
            params: { password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
            headers: auth_headers,
            as: :json
        expect(response).not_to have_http_status(:forbidden)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # PATCH com cookie de sessão
  describe "PATCH com cookie de sessão" do
    let(:patient_note) { create(:patient_note, user: client) }
    let(:auth_headers) { auth_headers_for(client) }

    before { auth_headers }

    context "sem X-CSRF-Token" do
      it "retorna 403" do
        patch clients_patient_note_path(patient_note),
              params: { content: "Conteúdo atualizado" },
              as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # POST com cookie de sessão
  describe "POST com cookie de sessão" do
    let(:auth_headers) { auth_headers_for(client) }

    before { auth_headers }

    context "sem X-CSRF-Token" do
      it "retorna 403 ao criar patient_note" do
        post clients_patient_notes_path,
             params: { content: "Nota de teste" },
             as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "com X-CSRF-Token correto" do
      it "não retorna 403 (CSRF passa, chega ao endpoint)" do
        post clients_patient_notes_path,
             params: { content: "Nota de teste" },
             headers: auth_headers,
             as: :json
        expect(response).not_to have_http_status(:forbidden)
        expect([201, 422]).to include(response.status)
      end
    end
  end

  # Sem cookie - CSRF ignorado, autenticação falha (401)
  describe "requisições sem cookie ignoram validação CSRF" do
    it "DELETE sem cookie retorna 401, não 403" do
      delete destroy_user_session_path, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(response).not_to have_http_status(:forbidden)
    end

    it "PUT sem cookie retorna 401, não 403" do
      put users_change_password_path,
          params: { password: "NovaSenha@456", password_confirmation: "NovaSenha@456" },
          as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(response).not_to have_http_status(:forbidden)
    end

    it "POST sem cookie retorna 401 ao tentar criar nota" do
      post clients_patient_notes_path,
           params: { patient_note: { content: "Nota" } },
           as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(response).not_to have_http_status(:forbidden)
    end
  end

  # Cookie com JWT malformado - derive retorna nil → 403
  describe "cookie com JWT malformado" do
    it "DELETE retorna 403 quando auth_token não é um JWT válido" do
      cookies["auth_token"] = "isso.nao.e.um.jwt"
      delete destroy_user_session_path, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "DELETE retorna 403 quando auth_token é uma string aleatória" do
      cookies["auth_token"] = "completamente_invalido"
      delete destroy_user_session_path, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "DELETE com X-CSRF-Token qualquer e cookie malformado ainda retorna 403" do
      cookies["auth_token"] = "nao.e.jwt"
      delete destroy_user_session_path,
             headers: { "X-CSRF-Token" => "qualquer_token" },
             as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  # Rotação de token - token da sessão anterior rejeitado após logout
  describe "CSRF token da sessão anterior não funciona após logout" do
    it "CSRF token antigo é rejeitado em nova sessão após logout" do
      first_headers = auth_headers_for(client)
      old_csrf      = first_headers["X-CSRF-Token"]

      delete destroy_user_session_path, headers: first_headers
      expect(response).to have_http_status(:no_content)

      auth_headers_for(client)

      delete destroy_user_session_path,
             headers: { "X-CSRF-Token" => old_csrf }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # Comparação segura - ActiveSupport::SecurityUtils.secure_compare
  describe "comparação segura de CSRF token" do
    it "rejeita token com comprimento correto mas valor errado" do
      auth_headers_for(client)

      wrong_token = "0" * 64
      delete destroy_user_session_path,
             headers: { "X-CSRF-Token" => wrong_token }
      expect(response).to have_http_status(:forbidden)
    end

    it "rejeita token parcialmente correto (prefixo válido, sufixo errado)" do
      headers  = auth_headers_for(client)
      correct  = headers["X-CSRF-Token"]
      tampered = correct[0..-2] + (correct[-1] == "a" ? "b" : "a")

      delete destroy_user_session_path,
             headers: { "X-CSRF-Token" => tampered }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
