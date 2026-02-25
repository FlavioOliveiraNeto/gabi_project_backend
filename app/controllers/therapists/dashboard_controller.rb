class Therapists::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!

  def index
    therapist = current_user

    sessions = Session
      .joins(:user)
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

  def ensure_therapist!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.therapist?
  end

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
    patients
      .includes(:weekly_schedules, :sessions, :clinical_notes)
      .map do |p|

      weekly_schedules = p.weekly_schedules.to_a
      weekly_count     = weekly_schedules.count

      # Usa registros já carregados em memória — evita N+1
      all_sessions  = p.sessions.sort_by(&:scheduled_at)
      by_status     = all_sessions.group_by(&:status)
      extra_sessions = all_sessions.select { |s| s.session_type == "extra" }

      schedule_type = weekly_count > 0 ? "regular" : "extra"

      {
        id: p.id,
        name: p.name,
        email: p.email,
        google_meet_link: p.google_meet_link,

        schedule_type: schedule_type,

        sessions_per_week: weekly_count > 0 ? weekly_schedules.first.sessions_per_week : nil,

        session_days: weekly_count > 0 ? weekly_schedules.map(&:weekday) : [],

        session_time: weekly_count > 0 ? weekly_schedules.first.time : nil,

        # extra_sessions exposto para TODOS os pacientes — regulares e avulsos
        extra_sessions: extra_sessions.map do |s|
          local_time = s.scheduled_at.in_time_zone(Time.zone)
          { id: s.id, date: local_time.to_date.iso8601, time: local_time.strftime("%H:%M"), status: s.status }
        end,

        completed_sessions: (by_status["completed"] || []).count,
        absent_sessions:    (by_status["absent"] || []).count,

        # Filtra notas clínicas em memória pela terapeuta atual — sem query adicional
        clinical_notes: p.clinical_notes
                          .select { |n| n.therapist_id == current_user.id }
                          .sort_by(&:created_at)
                          .reverse
                          .map { |n| { id: n.id, content: n.content, date: n.date, created_at: n.created_at } }
      }
    end
  end

  def build_calendar_sessions(sessions)
    sessions.map do |s|
      local_time = s.scheduled_at.in_time_zone(Time.zone)
      {
        id: s.id,
        date: local_time.to_date.iso8601,
        time: local_time.strftime("%H:%M"),
        status: s.status,
        session_type: s.session_type,
        patient: {
          id: s.user.id,
          name: s.user.name,
          google_meet_link: s.user.google_meet_link
        }
      }
    end
  end
end
