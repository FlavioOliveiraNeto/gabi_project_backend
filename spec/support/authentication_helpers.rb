module AuthenticationHelpers
  def auth_headers_for(user)
    post user_session_path,
         params: { user: { email: user.email, password: user.password } },
         as: :json

    raise "Login falhou para #{user.email}: #{response.body}" unless response.status == 200

    csrf_token = JSON.parse(response.body)["csrf_token"]
    raise "CSRF token ausente no login de #{user.email}" if csrf_token.blank?

    { "X-CSRF-Token" => csrf_token }
  end

  def json_body
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end
end
