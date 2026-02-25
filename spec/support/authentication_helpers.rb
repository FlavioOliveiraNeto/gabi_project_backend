module AuthenticationHelpers
  # Faz login via POST e devolve os headers com o JWT para usar nas requests subsequentes.
  def auth_headers_for(user)
    post user_session_path,
         params: { user: { email: user.email, password: user.password } },
         as: :json

    token = response.headers["Authorization"]
    raise "Login falhou para #{user.email}: #{response.body}" if token.blank?

    { "Authorization" => token }
  end

  # Parse do body da resposta como JSON.
  def json_body
    JSON.parse(response.body)
  end
end
