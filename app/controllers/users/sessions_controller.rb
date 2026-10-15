class Users::SessionsController < Devise::SessionsController
  respond_to :json

  skip_before_action :validate_csrf_token!, only: :create

  # Login é isento de CSRF; exigir JSON força o preflight CORS e impede que um
  # form de outro site logue a vítima na conta do atacante (login CSRF).
  before_action :require_json!, only: :create

  private

  def require_json!
    head :unsupported_media_type unless request.media_type == "application/json"
  end

  def verify_signed_out_user
    warden.authenticate(scope: resource_name)
    super
  end

  def respond_with(resource, _opts = {})
    jwt_token = request.env.delete("warden-jwt_auth.token")
    set_auth_cookie(jwt_token) if jwt_token.present?

    csrf = derive_login_csrf_token(jwt_token, resource)

    render json: {
      user: {
        id:                   resource.id,
        name:                 resource.name,
        email:                resource.email,
        role:                 resource.role,
        must_change_password: resource.must_change_password?
      },
      csrf_token: csrf
    }, status: :ok
  end

  def respond_to_on_destroy(non_navigational_status: :no_content)
    clear_auth_cookie
    head non_navigational_status
  end

  def derive_login_csrf_token(jwt_token, resource)
    return nil unless jwt_token.present?

    hmac_csrf(resource.id, decode_jwt(jwt_token)["jti"])
  rescue JWT::DecodeError
    nil
  end
end
