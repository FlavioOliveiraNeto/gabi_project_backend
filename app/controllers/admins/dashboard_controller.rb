class Admins::DashboardController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize :admin
    
    clients = User.where(role: :client).order(created_at: :desc)

    data = clients.map do |client|
      {
        id: client.id,
        email: client.email,
        sessions_count: client.sessions_count,
        google_meet_link: client.google_meet_link,
        notes: client.try(:clinical_notes) || [] 
      }
    end

    render json: { clients: data }, status: :ok
  end
end
