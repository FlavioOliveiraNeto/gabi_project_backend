class Clients::DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    unless current_user.client?
      render json: { error: "Acesso restrito a clientes." }, status: :forbidden
      return
    end

    @client_profile = {
      email: current_user.email,
      sessions_count: current_user.sessions_count,
      google_meet_link: current_user.google_meet_link
    }
    render json: @client_profile
  end
end
