class Clients::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_client!
  before_action :enforce_password_change!

  def index
    render json: {
      profile: build_profile,
      stats: build_stats,
      next_session: next_session_for(current_user),
      notes: build_notes
    }
  end

  private

  def ensure_client!
    render json: { error: "Acesso restrito a clientes." }, status: :forbidden unless current_user.client?
  end

  def build_profile
    {
      name: current_user.name,
      email: current_user.email,
      phone: current_user.phone,
      google_meet_link: current_user.google_meet_link
    }
  end

  def build_stats
    sessions = current_user.sessions

    {
      completed_sessions: sessions.where(status: :completed).count,
      absent_sessions: sessions.where(status: :absent).count
    }
  end

  def next_session_for(user)
    next_session = user.sessions
                       .where(status: :scheduled)
                       .where("scheduled_at >= ?", Time.zone.now)
                       .order(:scheduled_at)
                       .first

    return nil unless next_session

    {
      id: next_session.id,
      date: next_session.scheduled_at.to_date.iso8601,
      time: next_session.scheduled_at.strftime("%H:%M"),
      weekday: next_session.scheduled_at.strftime("%A").downcase,
      session_type: next_session.session_type,
      status: next_session.status
    }
  end

  def build_notes
    current_user.patient_notes
                .order(created_at: :desc)
                .map do |note|
      {
        id: note.id,
        content: note.content,
        created_at: note.created_at
      }
    end
  end
end