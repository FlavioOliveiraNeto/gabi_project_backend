require "rails_helper"

RSpec.describe JwtCookieToHeader do
  subject(:middleware) { described_class.new(inner_app) }

  let(:captured_env) { {} }
  let(:inner_app) do
    lambda do |env|
      captured_env.merge!(env)
      [200, {}, ["OK"]]
    end
  end

  VALID_JWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature"

  def call_middleware(cookie: nil, authorization: nil, method: "GET")
    env = Rack::MockRequest.env_for("http://example.com/some/path", method: method)
    env["HTTP_COOKIE"]        = cookie        if cookie
    env["HTTP_AUTHORIZATION"] = authorization if authorization
    status, headers, body = middleware.call(env)
    { status: status, headers: headers, body: body.join, env: captured_env }
  end

  # Injeção do cookie como Authorization header
  describe "injeção do cookie como Authorization header" do
    before { call_middleware(cookie: "auth_token=#{VALID_JWT}") }

    it "injeta 'Authorization: Bearer <token>' a partir do cookie auth_token" do
      expect(captured_env["HTTP_AUTHORIZATION"]).to eq("Bearer #{VALID_JWT}")
    end

    it "passa a requisição ao app interno com status 200" do
      expect(captured_env).not_to be_empty
    end
  end

  describe "extração do auth_token quando há múltiplos cookies" do
    it "injeta somente o valor de auth_token ignorando os demais cookies" do
      call_middleware(cookie: "session=abc123; auth_token=#{VALID_JWT}; locale=pt-BR")
      expect(captured_env["HTTP_AUTHORIZATION"]).to eq("Bearer #{VALID_JWT}")
    end
  end

  describe "não adiciona campos além de HTTP_AUTHORIZATION ao env" do
    it "preserva REQUEST_METHOD e outros headers originais" do
      call_middleware(
        cookie: "auth_token=#{VALID_JWT}",
        method: "POST"
      )
      expect(captured_env["REQUEST_METHOD"]).to eq("POST")
    end
  end
  
  # Preservação do Authorization header existente
  describe "preservação do Authorization header existente" do
    it "não substitui o header Authorization quando já está presente" do
      result = call_middleware(
        cookie: "auth_token=#{VALID_JWT}",
        authorization: "Bearer existing.token"
      )
      expect(result[:env]["HTTP_AUTHORIZATION"]).to eq("Bearer existing.token")
    end
  end

  # Sem cookie auth_token — noop
  describe "sem cookie auth_token" do
    it "não define HTTP_AUTHORIZATION quando não há cookies" do
      call_middleware
      expect(captured_env["HTTP_AUTHORIZATION"]).to be_nil
    end

    it "não define HTTP_AUTHORIZATION quando há outros cookies mas não auth_token" do
      call_middleware(cookie: "session=abc; locale=pt-BR")
      expect(captured_env["HTTP_AUTHORIZATION"]).to be_nil
    end

    it "não define HTTP_AUTHORIZATION quando auth_token tem valor vazio" do
      call_middleware(cookie: "auth_token=")
      expect(captured_env["HTTP_AUTHORIZATION"]).to be_nil
    end

    it "não define HTTP_AUTHORIZATION quando cookie é uma string vazia" do
      call_middleware(cookie: "")
      expect(captured_env["HTTP_AUTHORIZATION"]).to be_nil
    end

    it "não define HTTP_AUTHORIZATION quando HTTP_COOKIE está ausente no env" do
      env = Rack::MockRequest.env_for("http://example.com/")
      env.delete("HTTP_COOKIE")
      middleware.call(env)
      expect(env["HTTP_AUTHORIZATION"]).to be_nil
    end
  end

  # Token com estrutura inválida — proteção CSRF
  describe "token com estrutura inválida — proteção CSRF" do
    let(:invalid_token) { "nao.e.jwt.valido.de.verdade" }

    context "quando o método HTTP não é seguro (POST/PUT/PATCH/DELETE)" do
      subject(:response) do
        call_middleware(cookie: "auth_token=#{invalid_token}", method: "POST")
      end

      it "retorna status 403" do
        expect(response[:status]).to eq(403)
      end

      it "retorna JSON com mensagem de erro CSRF" do
        body = JSON.parse(response[:body])
        expect(body["error"]).to eq("Requisição inválida (CSRF).")
      end

      it "não chama o app interno" do
        response
        expect(captured_env).to be_empty
      end

      it "retorna 403 também para PUT, PATCH e DELETE" do
        %w[PUT PATCH DELETE].each do |verb|
          captured_env.clear
          result = call_middleware(cookie: "auth_token=#{invalid_token}", method: verb)
          expect(result[:status]).to eq(403), "esperava 403 para #{verb}"
        end
      end
    end

    context "quando o método HTTP é seguro (GET/HEAD/OPTIONS)" do
      it "não injeta HTTP_AUTHORIZATION e passa ao app normalmente" do
        call_middleware(cookie: "auth_token=#{invalid_token}", method: "GET")
        expect(captured_env["HTTP_AUTHORIZATION"]).to be_nil
      end

      it "retorna status 200 (app interno é chamado)" do
        result = call_middleware(cookie: "auth_token=#{invalid_token}", method: "GET")
        expect(result[:status]).to eq(200)
      end
    end
  end
  
  # valid_jwt_structure? — variações de token malformado em método POST
  describe "valid_jwt_structure? — tokens malformados bloqueiam métodos não-seguros" do
    def expect_403_for(token)
      result = call_middleware(cookie: "auth_token=#{token}", method: "POST")
      expect(result[:status]).to eq(403)
    end

    it "rejeita token sem nenhum ponto (segmento único)" do
      expect_403_for("tokenSemPontos")
    end

    it "rejeita token com apenas um ponto (dois segmentos)" do
      expect_403_for("header.payload")
    end

    it "rejeita token cujo header não é Base64 decodável" do
      expect_403_for("###invalido###.payload.sig")
    end

    it "rejeita token cujo header decodifica mas não é JSON" do
      # Base64url de "not-json" → "bm90LWpzb24"
      expect_403_for("bm90LWpzb24.payload.sig")
    end

    it "rejeita token cujo header é JSON Array e não Hash" do
      # Base64url de "[]" → "W10"
      expect_403_for("W10.payload.sig")
    end
  end
end
