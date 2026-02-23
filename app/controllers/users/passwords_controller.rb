class Users::PasswordsController < ApplicationController
  before_action :authenticate_user!

  def update
    unless current_user.client?
      render json: { error: "Acesso restrito." }, status: :forbidden
      return
    end

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
      render json: { success: true }
    else
      render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end
end
