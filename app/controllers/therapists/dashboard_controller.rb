class Therapists::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!

  CALENDAR_MONTHS_BACK    = 3
  CALENDAR_MONTHS_FORWARD = 3

  def index
    therapist = current_user

    sessions = Session
      .includes(:user)
      .where(therapist_id: therapist.id)
      .where(start_time: calendar_window)
      .order(:start_time)

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

  def calendar_window
    from = parse_date(params[:from]) || CALENDAR_MONTHS_BACK.months.ago.beginning_of_month.to_date
    to   = parse_date(params[:to])   || CALENDAR_MONTHS_FORWARD.months.from_now.end_of_month.to_date

    to = from + 12.months if to > from + 12.months

    from.beginning_of_day..to.end_of_day
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end

  def build_stats(therapist)
    sessions = Session.where(therapist_id: therapist.id)

    {
      active_clients: therapist.patients.count,
      sessions_today: sessions.where(start_time: Time.zone.now.all_day).count,
      sessions_this_week: sessions.where(start_time: Time.zone.now.all_week).count,
      sessions_completed_this_week: sessions
        .where(status: :completed)
        .where(start_time: Time.zone.now.all_week)
        .count
    }
  end

  def build_patients(patients)
    patients.includes(:weekly_schedules, :sessions).map do |p|
      all_schedules    = p.weekly_schedules.to_a
      active_schedules = all_schedules.select(&:active?)

      all_sessions  = p.sessions.sort_by(&:start_time)
      by_status     = all_sessions.group_by(&:status)
      extra_sessions = all_sessions.select { |s| s.session_type == "extra" }

      schedule_type = active_schedules.any? ? "regular" : "extra"

      {
        id: p.id,
        name: p.name,
        email: p.email,
        google_meet_link: p.google_meet_link,

        schedule_type: schedule_type,

        sessions_per_week: active_schedules.first&.sessions_per_week,

        session_days: active_schedules.map(&:weekday),

        session_time: active_schedules.first&.time,

        schedule_slots: active_schedules
                          .sort_by { |sch| WeeklySchedule.weekdays[sch.weekday] }
                          .map { |sch| { weekday: sch.weekday, time: sch.time } },

        extra_sessions: extra_sessions.map do |s|
          local_time = s.start_time.in_time_zone(Time.zone)
          { id: s.id, date: local_time.to_date.iso8601, time: local_time.strftime("%H:%M"), status: s.status }
        end,

        completed_sessions: (by_status["completed"] || []).count,
        absent_sessions:    (by_status["absent"] || []).count,

        clinical_notes_count: notes_count_by_patient[p.id] || 0
      }
    end
  end

  def notes_count_by_patient
    @notes_count_by_patient ||= ClinicalNote
      .where(therapist_id: current_user.id)
      .group(:user_id)
      .count
  end

  def build_calendar_sessions(sessions)
    sessions.map do |s|
      local_time = s.start_time.in_time_zone(Time.zone)
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
