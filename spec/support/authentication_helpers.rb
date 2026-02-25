module AuthenticationHelpers
  # Faz login via POST e devolve os headers com o JWT para usar nas requests subsequentes.
  def auth_headers_for(user)
    post user_session_path,
         params: { user: { email: user.email, password: user.password } },
         as: :json

    token = response.headers["Authorization"]
    raise "Login falhou para #{user.email}: #{response.body}" if token.blank?

    { "Authorization" => token, "Content-Type" => "application/json" }
  end
end
