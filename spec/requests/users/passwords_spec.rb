require "rails_helper"

RSpec.describe "Users::Passwords (Troca de Senha)", type: :request do
  let(:therapist)    { create(:user, :therapist) }
  let(:user)         { create(:user, :client, therapist: therapist, password: "Password@123") }
  let(:auth_headers) { auth_headers_for(user) }

  # PUT /users/change_password - Users::PasswordsController#update
  describe "PUT /users/change_password" do
    let(:valid_params) do
      { password: "NovaSenha@456", password_confirmation: "NovaSenha@456" }
    end

    context "sem autenticação" do
      it "retorna 401" do
        put users_change_password_path, params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "com dados válidos" do
      before do
        put users_change_password_path,
            params: valid_params,
            headers: auth_headers,
            as: :json
      end

      it "retorna 200 com success: true" do
        expect(response).to have_http_status(:ok)
        expect(json_body["success"]).to be true
      end

      it "atualiza a senha no banco" do
        expect(user.reload.valid_password?("NovaSenha@456")).to be true
      end

      it "limpa a flag must_change_password" do
        # O controller chama clear_must_change_password! incondicionalmente.
        expect(user.reload.must_change_password).to be false
      end

      it "limpa o cookie auth_token na resposta" do
        expect(response.cookies["auth_token"]).to be_blank
      end

      it "adiciona o JTI à denylist" do
        expect(JwtDenylist.count).to eq(1)
      end

      it "token antigo retorna 401 em requisições subsequentes" do
        # Cookie persiste no jar da sessão de teste mas o JTI foi adicionado à denylist.
        get clients_dashboard_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "com must_change_password ativo" do
      before { user.update!(must_change_password: true) }

      it "limpa a flag após troca bem-sucedida" do
        put users_change_password_path,
            params: valid_params,
            headers: auth_headers,
            as: :json

        expect(user.reload.must_change_password).to be false
      end
    end

    context "como terapeuta autenticado" do
      let(:therapist_user)    { create(:user, :therapist) }
      let(:therapist_headers) { auth_headers_for(therapist_user) }

      it "retorna 200 (qualquer role autenticada pode trocar a própria senha)" do
        put users_change_password_path,
            params: valid_params,
            headers: therapist_headers,
            as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "com senhas que não coincidem" do
      let(:mismatched_params) do
        { password: "NovaSenha@456", password_confirmation: "Diferente@999" }
      end

      before do
        put users_change_password_path,
            params: mismatched_params,
            headers: auth_headers,
            as: :json
      end

      it "retorna 422" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "inclui mensagem de erro em português" do
        expect(json_body["error"]).to match(/não coincidem/)
      end

      it "não altera a senha no banco" do
        expect(user.reload.valid_password?("Password@123")).to be true
      end

      it "não revoga o JWT - usuário continua acessível com o token anterior" do
        get clients_dashboard_path, headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "com password em branco" do
      it "retorna 422 com mensagem de obrigatoriedade" do
        put users_change_password_path,
            params: { password: "", password_confirmation: "" },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["error"]).to match(/obrigatórias/)
      end
    end

    context "com password muito curta (< 6 caracteres - validação do modelo)" do
      it "retorna 422" do
        put users_change_password_path,
            params: { password: "abc", password_confirmation: "abc" },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "com cookie válido mas sem X-CSRF-Token" do
      # auth_headers_for faz login e persiste o cookie no jar da sessão de teste.
      # O retorno (CSRF header) é intencionalmente descartado para simular CSRF ausente.
      before { auth_headers_for(user) }

      it "retorna 403 (CSRF bloqueado)" do
        put users_change_password_path,
            params: valid_params,
            as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_body["error"]).to match(/CSRF/)
      end
    end

    context "com cookie válido mas X-CSRF-Token incorreto" do
      before { auth_headers_for(user) }

      it "retorna 403" do
        put users_change_password_path,
            params: valid_params,
            headers: { "X-CSRF-Token" => "invalido" },
            as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # POST /users/password - DevisePasswordsController#create (solicitar reset)
  describe "POST /users/password (solicitar reset por e-mail)" do
    let!(:target_user) { create(:user, :client, email: "reset@example.com", therapist: therapist) }

    context "com e-mail existente" do
      it "retorna 200 com mensagem de instrução" do
        post user_password_path,
             params: { user: { email: "reset@example.com" } },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(json_body["message"]).to be_present
      end
    end

    context "com e-mail inexistente" do
      it "retorna 200 (anti-enumeração - não revela se e-mail existe)" do
        post user_password_path,
             params: { user: { email: "naoexiste@example.com" } },
             as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "sem X-CSRF-Token (usuário não autenticado)" do
      it "não retorna 403 - endpoint público não exige CSRF" do
        post user_password_path,
             params: { user: { email: "reset@example.com" } },
             as: :json

        expect(response).not_to have_http_status(:forbidden)
      end
    end

    context "rate limiting" do
      it "retorna 429 após 5 tentativas consecutivas" do
        6.times do
          post user_password_path,
               params: { user: { email: "reset@example.com" } },
               as: :json
        end

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  # PUT /users/password - DevisePasswordsController#update (confirmar reset)
  describe "PUT /users/password (confirmar reset por token)" do
    let!(:target_user) { create(:user, :client, email: "reset@example.com", therapist: therapist) }

    let(:valid_reset_params) do
      {
        password: "NovaSenha@456",
        password_confirmation: "NovaSenha@456"
      }
    end

    context "com token válido" do
      let(:reset_token) { target_user.send_reset_password_instructions }

      it "retorna 200 com mensagem de sucesso" do
        put user_password_path,
            params: { user: valid_reset_params.merge(reset_password_token: reset_token) },
            as: :json

        expect(response).to have_http_status(:ok)
        expect(json_body["message"]).to be_present
      end

      it "limpa a flag must_change_password quando estava ativa" do
        target_user.update!(must_change_password: true)

        put user_password_path,
            params: { user: valid_reset_params.merge(reset_password_token: reset_token) },
            as: :json

        expect(target_user.reload.must_change_password).to be false
      end
    end

    context "com token válido mas senhas inválidas" do
      let(:reset_token) { target_user.send_reset_password_instructions }

      it "retorna 422 quando as senhas não coincidem" do
        put user_password_path,
            params: {
              user: {
                password: "NovaSenha@456",
                password_confirmation: "Diferente@999",
                reset_password_token: reset_token
              }
            },
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end

      it "retorna 422 quando a senha é muito curta" do
        put user_password_path,
            params: {
              user: {
                password: "abc",
                password_confirmation: "abc",
                reset_password_token: reset_token
              }
            },
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end
    end

    context "com token inválido" do
      it "retorna 422 com mensagem de erro" do
        put user_password_path,
            params: { user: valid_reset_params.merge(reset_password_token: "token_invalido") },
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body["errors"]).to be_present
      end
    end

    context "com token ausente" do
      it "retorna 422" do
        put user_password_path,
            params: { user: valid_reset_params },
            as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
