module Helpers
  module AuthenticationHelper
    # ===========================================================================
    # Ponto de integração JWT
    # ---------------------------------------------------------------------------
    # O projeto usa Devise + devise-jwt com autenticação via cookie httpOnly.
    # O token é gerado no login e devolvido como cookie `auth_token`
    # (Set-Cookie), nunca no body ou no header Authorization. A resposta de
    # login também devolve `csrf_token` no body, que deve ser enviado no header
    # `X-CSRF-Token` em toda requisição não segura (POST/PUT/PATCH/DELETE).
    #
    # Estratégia: fazemos um POST real ao endpoint de sign_in. O cookie
    # `auth_token` fica automaticamente armazenado no jar de cookies do
    # request spec (persiste entre requests do mesmo exemplo); só precisamos
    # repassar o `X-CSRF-Token` nos headers.
    #
    # Se o endpoint de login mudar, ajuste LOGIN_PATH abaixo.
    # ===========================================================================

    LOGIN_PATH = "/users/sign_in"
    private_constant :LOGIN_PATH

    # Autentica qualquer User (login real, cookie httpOnly gravado no jar do
    # request spec) e retorna os headers HTTP prontos para uso (CSRF).
    #
    # Uso:
    #   get "/api/v1/patients", headers: auth_headers(therapist)
    #
    def auth_headers(user)
      post LOGIN_PATH, params: { user: { email: user.email, password: user.password } }, as: :json

      raise "auth_headers: login falhou (status #{response.status}). Body: #{response.body}" unless response.status == 200

      csrf_token = JSON.parse(response.body)["csrf_token"]

      raise "auth_headers: csrf_token não retornado. Verifique se #{LOGIN_PATH} está roteado " \
            "e se o User tem email/password válidos." if csrf_token.blank?

      json_headers_with(csrf_token)
    end

    # Atalho retrocompatível — specs de CSRF/cookie escritos antes da
    # renomeação do helper usam `auth_headers_for`.
    alias_method :auth_headers_for, :auth_headers

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

    # Headers sem token de autenticação (sem cookie, sem CSRF).
    # Use para testar cenários de 401 por ausência de credencial.
    #
    def unauthenticated_headers
      {
        "Content-Type" => "application/json",
        "Accept"       => "application/json"
      }
    end

    # Headers com cookie de autenticação sintaticamente inválido (JWT malformado).
    # Use para testar cenários de 401 por credencial corrompida.
    #
    def invalid_token_headers
      unauthenticated_headers.merge("Cookie" => "auth_token=token.invalido.xyz")
    end

    # Headers com cookie de autenticação expirado usando Timecop.
    #
    # Faz login com o relógio 2 dias no passado (além do TTL padrão de 30min
    # do devise-jwt), o que grava no jar de cookies do request spec um
    # `auth_token` cujo `exp` já passou quando o relógio volta ao presente.
    # devise-jwt rejeita a requisição seguinte com 401.
    #
    # IMPORTANTE: Timecop.return é chamado automaticamente pelo
    # spec/support/timecop.rb depois de cada exemplo — não é necessário fazer
    # cleanup manual aqui.
    #
    def expired_token_headers(user)
      Timecop.travel(2.days.ago) do
        post LOGIN_PATH, params: { user: { email: user.email, password: user.password } }, as: :json
      end

      csrf_token = JSON.parse(response.body)["csrf_token"]
      json_headers_with(csrf_token)
    end

    private

    def json_headers_with(csrf_token)
      {
        "X-CSRF-Token" => csrf_token,
        "Content-Type" => "application/json",
        "Accept"       => "application/json"
      }
    end
  end
end
