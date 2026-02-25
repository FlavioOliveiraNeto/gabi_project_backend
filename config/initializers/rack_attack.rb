Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test?

class Rack::Attack
  throttle("login/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  throttle("signup/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/users" && req.post?
  end

  throttle("password_reset/ip", limit: 5, period: 5.minutes) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  self.throttled_responder = lambda do |_env|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Muitas tentativas. Tente novamente em instantes." }.to_json]
    ]
  end
end
