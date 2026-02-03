class Clients::DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    unless current_user.client?
      flash.now[:alert] = "Acesso restrito a clientes."
      return render :index, status: :forbidden
    end

    @client_profile = {
      email: current_user.email,
      sessions_count: current_user.sessions_count,
      google_meet_link: current_user.google_meet_link
    }
  end
end
