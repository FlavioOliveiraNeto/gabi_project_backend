class Rack::Attack
  throttle("login/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  self.throttled_responder = lambda do |_env|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Muitas tentativas. Tente novamente em 1 minuto." }.to_json]
    ]
  end
end
