class JwtCookieToHeader
  def initialize(app)
    @app = app
  end

  SAFE_METHODS = %w[GET HEAD OPTIONS].freeze

  def call(env)
    if env["HTTP_COOKIE"].to_s.include?("auth_token=") &&
        env["HTTP_AUTHORIZATION"].blank?

      cookies = Rack::Utils.parse_cookies(env)
      token   = cookies["auth_token"]

      if token.present?
        if valid_jwt_structure?(token)
          env["HTTP_AUTHORIZATION"] = "Bearer #{token}"
        elsif !SAFE_METHODS.include?(env["REQUEST_METHOD"])
          return [403, { "Content-Type" => "application/json" },
                  ['{"error":"Requisição inválida (CSRF)."}']]
        end
      end
    end

    @app.call(env)
  end

  private

  def valid_jwt_structure?(token)
    return false unless token.to_s.count(".") == 2

    header_b64 = token.split(".").first
    padded     = header_b64 + "=" * ((4 - header_b64.length % 4) % 4)
    header     = Base64.urlsafe_decode64(padded)
    JSON.parse(header).is_a?(Hash)
  rescue ArgumentError, JSON::ParserError
    false
  end
end
