Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

class Rack::Attack
  EMAIL_ENV_KEY = "gabi.throttle.login_email"

  def self.normalized_login(req)
    unless req.env.key?(EMAIL_ENV_KEY)
      req.env[EMAIL_ENV_KEY] = extract_login(req).to_s.downcase.strip
    end

    req.env[EMAIL_ENV_KEY].presence
  end

  def self.extract_login(req)
    return nil unless req.post?

    payload = if req.media_type.to_s.include?("json")
      parse_json_body(req)
    else
      req.params
    end

    return nil unless payload.is_a?(Hash)

    payload.dig("user", "email") || payload["email"]
  rescue StandardError
    nil
  end

  def self.parse_json_body(req)
    body = req.body
    return nil unless body

    raw = body.read
    body.rewind if body.respond_to?(:rewind)

    return nil if raw.blank?

    JSON.parse(raw)
  end

  PASSWORD_WRITE_PATHS = %w[/users/password /users/change_password].freeze

  throttle("login/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("login/email", limit: 10, period: 20.minutes) do |req|
    normalized_login(req) if req.path == "/users/sign_in"
  end

  throttle("password_reset/ip", limit: 5, period: 5.minutes) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  throttle("password_reset/email", limit: 5, period: 1.hour) do |req|
    normalized_login(req) if req.path == "/users/password"
  end

  throttle("password_write/ip", limit: 10, period: 1.hour) do |req|
    req.ip if PASSWORD_WRITE_PATHS.include?(req.path) && !req.get?
  end

  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path == "/up"
  end

  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period].to_i

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After"  => retry_after.to_s
      },
      [ { error: "Muitas tentativas. Tente novamente em instantes." }.to_json ]
    ]
  end
end
