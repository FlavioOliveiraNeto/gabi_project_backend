class Users::PasswordsController < ApplicationController
  before_action :authenticate_user!

  def update
    current_password = params[:current_password]
    password = params[:password]
    password_confirmation = params[:password_confirmation]

    unless current_user.must_change_password?
      if current_password.blank?
        render json: { error: "Senha atual é obrigatória." }, status: :unprocessable_entity
        return
      end

      unless current_user.valid_password?(current_password)
        render json: { error: "Senha atual incorreta." }, status: :unprocessable_entity
        return
      end
    end

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
      clear_auth_cookie
      render json: { success: true }
    else
      render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  def revoke_current_jwt!
    token = request.cookies["auth_token"] ||
            request.headers["Authorization"]&.split(" ")&.last
    return unless token.present?

    secret  = Rails.application.credentials.devise_jwt_secret_key || Rails.application.secret_key_base
    payload, = JWT.decode(token, secret, true, algorithms: [ "HS256" ])
    return unless payload["jti"].present?

    JwtDenylist.revoke_jwt(payload, current_user)
  rescue JWT::DecodeError
    Rails.logger.error "Erro de decode do JWT."
  end
end
