class Users::PasswordsController < ApplicationController
  before_action :authenticate_user!

  def update
    password = params[:password]
    password_confirmation = params[:password_confirmation]

    if password.blank? || password_confirmation.blank?
      render json: { error: "Senha e confirmação são obrigatórias." }, status: :unprocessable_entity
      return
    end

    if password != password_confirmation
      render json: { error: "As senhas não coincidem." }, status: :unprocessable_entity
      return
    end

    if current_user.update(password: password, password_confirmation: password_confirmation)
      current_user.clear_must_change_password!
      revoke_current_jwt!
      render json: { success: true }
    else
      render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  def revoke_current_jwt!
    auth_header = request.headers["Authorization"]
    return unless auth_header&.start_with?("Bearer ")

    token = auth_header.split(" ").last
    payload, = JWT.decode(token, nil, false)
    return unless payload["jti"].present?

    JwtDenylist.revoke_jwt(payload, current_user)
  rescue JWT::DecodeError
    # token malformado — nada a revogar
  end
end
