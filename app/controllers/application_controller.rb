class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }

  prepend_before_action :validate_csrf_token!

  # Popula Current.user para que os callbacks de auditoria saibam quem agiu.
  before_action :set_current_user

  protected

  def set_current_user
    Current.user = current_user
  end

  def after_sign_in_path_for(resource)
    if resource.therapist?
      therapists_dashboard_path
    elsif resource.client?
      clients_dashboard_path
    else
      root_path
    end
  end

  def enforce_password_change!
    return unless current_user&.must_change_password?

    render json: {
      error: "É necessário trocar a senha antes de continuar.",
      must_change_password: true
    }, status: :forbidden
  end

  private

  def validate_csrf_token!
    return if safe_request?
    return unless request.cookies["auth_token"].present?

    provided = request.headers["X-CSRF-Token"]
    expected = derive_csrf_token_from_cookie

    return if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected.to_s)

    render json: { error: "Requisição inválida (CSRF)." }, status: :forbidden
  end

  def derive_csrf_token_from_cookie
    token = request.cookies["auth_token"]
    return nil unless token.present?

    payload, = JWT.decode(token, nil, false)
    user_id  = payload["sub"]
    jti      = payload["jti"]

    hmac_csrf(user_id, jti)
  rescue JWT::DecodeError
    nil
  end

  def generate_csrf_token
    return nil unless current_user

    raw_token = response.headers["Authorization"]&.split(" ")&.last ||
                request.cookies["auth_token"]
    return nil unless raw_token.present?

    payload, = JWT.decode(raw_token, nil, false)
    hmac_csrf(current_user.id, payload["jti"])
  rescue JWT::DecodeError
    nil
  end

  def hmac_csrf(user_id, jti)
    secret = Rails.application.credentials.devise_jwt_secret_key ||
             Rails.application.secret_key_base
    OpenSSL::HMAC.hexdigest("SHA256", secret, "csrf:#{user_id}:#{jti}")
  end

  def set_auth_cookie(token)
    cookies[:auth_token] = {
      value:     token,
      httponly:  true,
      secure:    Rails.env.production?,
      same_site: Rails.env.production? ? :none : :lax,
      max_age:   Warden::JWTAuth.config.expiration_time,
      path:      "/"
    }
  end

  def clear_auth_cookie
    cookies.delete(:auth_token, {
      secure:    Rails.env.production?,
      same_site: Rails.env.production? ? :none : :lax,
      path:      "/"
    })
  end

  def safe_request?
    request.get? || request.head? || request.options?
  end
end
