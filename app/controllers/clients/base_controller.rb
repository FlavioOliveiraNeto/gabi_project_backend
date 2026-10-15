# Autenticação e papel num lugar só: todo controller de /clients herda daqui,
# então um endpoint novo não tem como esquecer as checagens.
class Clients::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_client!
  before_action :enforce_password_change!

  private

  def ensure_client!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.client?
  end
end
