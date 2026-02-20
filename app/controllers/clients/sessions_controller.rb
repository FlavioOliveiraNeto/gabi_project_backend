class Clients::SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_client!

  def index
    sessions = current_user.sessions.order(:scheduled_at)
    render json: sessions
  end

  private

  def ensure_client!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.client?
  end
end