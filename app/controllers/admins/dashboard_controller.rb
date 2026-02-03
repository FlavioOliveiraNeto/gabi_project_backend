class Admins::DashboardController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize :admin

    @clients = User.where(role: :client).order(created_at: :desc)
    @stats = {
      active_clients: @clients.count,
      sessions_this_week: @clients.sum(:sessions_count),
      upcoming_sessions: @clients.count { |client| client.google_meet_link.present? }
    }
  end
end
