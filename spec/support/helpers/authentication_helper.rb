module Helpers
  module AuthenticationHelper
    # ===========================================================================
    # Ponto de integração JWT
    # ---------------------------------------------------------------------------
    # O projeto usa Devise + devise-jwt. O token é gerado no login e devolvido
    # no header `Authorization: Bearer <token>` da resposta.
    #
    # Estratégia: fazemos um POST real ao endpoint de sign_in para obter o token,
    # capturamos o header e o reutilizamos nos requests seguintes.
    #
    # Pré-requisito de factory: o model User deve ter os campos `email` e
    # `password` (virtual) definidos. Ao criar via FactoryBot, o in-memory object
    # retém o valor de `password` (atributo virtual do Devise), então basta
    # passar `user.password` diretamente.
    #
    # Se o endpoint de login mudar, ajuste LOGIN_PATH abaixo.
    # ===========================================================================

    LOGIN_PATH = "/users/sign_in"
    private_constant :LOGIN_PATH

    # Autentica qualquer User e retorna os headers HTTP prontos para uso.
    #
    # Uso:
    #   get "/api/v1/patients", headers: auth_headers(therapist)
    #
    def auth_headers(user)
      post LOGIN_PATH, params: { user: { email: user.email, password: user.password } }, as: :json

      token = response.headers["Authorization"]

      raise "auth_headers: token não retornado. Verifique se #{LOGIN_PATH} está roteado " \
            "e se o User tem email/password válidos." if token.blank?

      json_headers_with(token)
    end

    # Atalho semântico para a terapeuta (role :therapist).
    #
    # Uso:
    #   get "/api/v1/patients", headers: therapist_auth_headers(therapist)
    #
    def therapist_auth_headers(therapist)
      auth_headers(therapist)
    end

    # Atalho semântico para o paciente (role :patient).
    #
    # Uso:
    #   get "/api/v1/sessions", headers: patient_auth_headers(patient_user)
    #
    def patient_auth_headers(patient_user)
      auth_headers(patient_user)
    end

    # Headers sem token de autenticação.
    # Use para testar cenários de 401 por ausência de credencial.
    #
    def unauthenticated_headers
      {
        "Content-Type" => "application/json",
        "Accept"       => "application/json"
      }
    end

    # Headers com token sintaticamente inválido (JWT malformado).
    # Use para testar cenários de 401 por credencial corrompida.
    #
    def invalid_token_headers
      json_headers_with("Bearer token.invalido.xyz")
    end

    # Headers com token expirado usando Timecop.
    #
    # Gera um token válido e depois avança o relógio 2 dias (além do TTL padrão
    # do devise-jwt de 1 dia). O token passa a ter exp < current_time, então
    # devise-jwt rejeita com 401.
    #
    # IMPORTANTE: Timecop.return é chamado automaticamente pelo
    # spec/support/timecop.rb depois de cada exemplo — não é necessário fazer
    # cleanup manual aqui.
    #
    def expired_token_headers(user)
      headers = auth_headers(user)
      Timecop.travel(2.days.from_now)
      headers
    end

    private

    def json_headers_with(authorization)
      {
        "Authorization" => authorization,
        "Content-Type"  => "application/json",
        "Accept"        => "application/json"
      }
    end
  end
end
