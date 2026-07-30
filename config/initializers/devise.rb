Devise.setup do |config|
  require "devise/orm/active_record"

  config.mailer_sender = ENV.fetch("MAIL_FROM", "no-reply@gabi.local")

  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]

  config.skip_session_storage = [ :http_auth ]

  config.stretches = Rails.env.test? ? 1 : 12

  config.expire_all_remember_me_on_sign_out = true

  config.password_length = 12..128

  config.email_regexp = /\A[^@\s]+@([^@\s]+\.)+[^@\s]+\z/

  config.reset_password_within = 6.hours

  config.lock_strategy = :failed_attempts
  config.maximum_attempts = 10

  config.unlock_strategy = :time
  config.unlock_in = 1.hour

  config.last_attempt_warning = false
  config.paranoid = true

  config.navigational_formats = []

  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other

  jwt_secret = ENV["DEVISE_JWT_SECRET_KEY"].presence ||
               Rails.application.credentials.devise_jwt_secret_key.presence

  if jwt_secret.blank?
    build_time = ENV["SECRET_KEY_BASE_DUMMY"].present?

    if Rails.env.production? && !build_time
      raise "[Devise JWT] DEVISE_JWT_SECRET_KEY não configurado no ambiente de produção! " \
            "Sem ele os JWTs seriam assinados com o secret_key_base, e rotacionar um " \
            "arrastaria o outro."
    end

    jwt_secret = Rails.application.secret_key_base
  end

  config.jwt do |jwt|
    jwt.secret = jwt_secret

    jwt.dispatch_requests = [
      [ "POST", %r{^/users/sign_in$} ]
    ]

    jwt.revocation_requests = [
      [ "DELETE", %r{^/users/sign_out$} ]
    ]

    jwt.expiration_time = 30.minutes.to_i
  end
end
