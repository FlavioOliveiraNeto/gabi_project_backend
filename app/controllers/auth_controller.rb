class AuthController < ApplicationController
  before_action :authenticate_user!

  def me
    render json: {
      user: {
        id:                   current_user.id,
        name:                 current_user.name,
        email:                current_user.email,
        role:                 current_user.role,
        must_change_password: current_user.must_change_password?
      },
      csrf_token: generate_csrf_token
    }
  end
end
