class Users::SessionsController < Devise::SessionsController
  respond_to :json

  private

  # Devise 5 calls verify_signed_out_user before the JWT strategy runs,
  # so warden.user(run_callbacks: false) always returns nil with JWT auth.
  # Authenticate eagerly so the check works correctly.
  def verify_signed_out_user
    warden.authenticate(scope: resource_name)
    super
  end

  def respond_with(resource, _opts = {})
    render json: {
      user: {
        id: resource.id,
        name: resource.name,
        email: resource.email,
        role: resource.role,
        must_change_password: resource.must_change_password?
      }
    }, status: :ok
  end

  def respond_to_on_destroy(non_navigational_status: :no_content)
    head non_navigational_status
  end
end
