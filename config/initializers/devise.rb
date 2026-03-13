Devise.setup do |config|
  require 'devise/orm/active_record'

  config.mailer_sender = 'no-reply@seudominio.com'

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  config.skip_session_storage = [:http_auth]

  config.stretches = Rails.env.test? ? 1 : 12

  config.expire_all_remember_me_on_sign_out = true

  config.password_length = 8..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  config.reset_password_within = 6.hours

  config.navigational_formats = []

  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other

  # JWT secret: obrigatório em produção. Em dev/test usa secret_key_base como fallback seguro.
  jwt_secret = Rails.application.credentials.devise_jwt_secret_key

  if jwt_secret.blank?
    raise "[Devise JWT] devise_jwt_secret_key não configurado nas credentials de produção!" if Rails.env.production?

    jwt_secret = Rails.application.secret_key_base
  end

  config.jwt do |jwt|
    jwt.secret = jwt_secret

    jwt.dispatch_requests = [
      ['POST', %r{^/users/sign_in$}]
    ]

    jwt.revocation_requests = [
      ['DELETE', %r{^/users/sign_out$}]
    ]

    jwt.expiration_time = 30.minutes.to_i
  end
end
