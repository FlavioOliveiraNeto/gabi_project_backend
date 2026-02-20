class Therapists::DashboardController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize :therapist

    patients = current_user.patients
                          .includes(:clinical_notes, :sessions, :weekly_schedules)
                          .order(created_at: :desc)

    today_weekday = Date.current.wday

    today_sessions = patients.joins(:weekly_schedules)
                            .where(weekly_schedules: { weekday: today_weekday })
                            .distinct
                            .count

    sessions_this_week = Session
      .joins(:user)
      .where(users: { therapist_id: current_user.id })
      .where(scheduled_at: Time.zone.now.all_week)
      .count

    stats = {
      active_clients: patients.count,
      today_sessions: today_sessions,
      sessions_this_week: sessions_this_week
    }

    render json: {
      clients: patients.map { |p| patient_json(p) },
      stats: stats
    }
  end

  private

  def patient_json(patient)
    schedules = patient.weekly_schedules
    {
      id: patient.id,
      name: patient.name,
      email: patient.email,
      google_meet_link: patient.google_meet_link,
      created_at: patient.created_at,
      sessions_per_week: schedules.first&.sessions_per_week || 0,
      session_days: schedules.map(&:weekday),
      session_time: schedules.first&.time,
      completed_sessions: patient.sessions.where(status: "completed").count,
      absent_sessions: patient.sessions.where(status: "absent").count,
      clinical_notes: patient.clinical_notes.sort_by(&:created_at).reverse.map do |n|
        { id: n.id, content: n.content, date: n.date, created_at: n.created_at }
      end
    }
  end
end
