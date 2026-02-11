Devise.setup do |config|
  require 'devise/orm/active_record'

  config.mailer_sender = 'no-reply@seudominio.com'

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  config.skip_session_storage = [:http_auth]

  config.stretches = Rails.env.test? ? 1 : 12

  config.reconfirmable = true

  config.expire_all_remember_me_on_sign_out = true

  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  config.reset_password_within = 6.hours

  config.navigational_formats = []

  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other

  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key || "temporary_build_key"

    jwt.dispatch_requests = [
      ['POST', %r{^/users/sign_in$}]
    ]

    jwt.revocation_requests = [
      ['DELETE', %r{^/users/sign_out$}]
    ]

    jwt.expiration_time = 30.minutes.to_i
  end
end
