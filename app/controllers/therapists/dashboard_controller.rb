class Therapists::DashboardController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  def index
    authorize :therapist
    Session.auto_complete_past_sessions!

    therapist = current_user

    sessions = Session
      .includes(:user)
      .where(users: { therapist_id: therapist.id })
      .order(:scheduled_at)

    patients = User
      .where(therapist_id: therapist.id)
      .distinct

    render json: {
      stats: build_stats(therapist),
      patients: build_patients(patients),
      calendar_sessions: build_calendar_sessions(sessions)
    }
  end

  private

  def build_stats(therapist)
    sessions = Session.joins(:user)
                      .where(users: { therapist_id: therapist.id })

    {
      active_clients: therapist.patients.count,
      sessions_today: sessions.where(scheduled_at: Time.zone.now.all_day).count,
      sessions_this_week: sessions.where(scheduled_at: Time.zone.now.all_week).count,
      sessions_completed_this_week: sessions
        .where(status: :completed)
        .where(scheduled_at: Time.zone.now.all_week)
        .count
    }
  end

  def build_patients(patients)
    patients.includes(:weekly_schedules).map do |p|
      schedules = p.weekly_schedules

      {
        id: p.id,
        name: p.name,
        email: p.email,
        google_meet_link: p.google_meet_link,
        sessions_per_week: schedules.first&.sessions_per_week,
        session_days: schedules.map(&:weekday),
        session_time: schedules.first&.time,
        completed_sessions: p.sessions.where(status: :completed).count,
        absent_sessions: p.sessions.where(status: :absent).count
      }
    end
  end

  def build_calendar_sessions(sessions)
    sessions.map do |s|
      {
        id: s.id,
        date: s.scheduled_at.to_date.iso8601,
        time: s.scheduled_at.strftime("%H:%M"),
        status: s.status,
        patient: {
          id: s.user.id,
          name: s.user.name,
          google_meet_link: s.user.google_meet_link
        }
      }
    end
  end
end