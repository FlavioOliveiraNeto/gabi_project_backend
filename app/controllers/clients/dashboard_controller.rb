class Clients::DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    unless current_user.client?
      return render json: { error: "Acesso restrito a clientes" }, status: :forbidden
    end

    render json: {
      user: {
        email: current_user.email,
        sessions_count: current_user.sessions_count,
        google_meet_link: current_user.google_meet_link
      }
    }, status: :ok
  end
end
