class Clients::DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    unless current_user.client?
      render json: { error: "Acesso restrito a clientes." }, status: :forbidden
      return
    end

    sessions  = current_user.sessions.to_a
    completed = sessions.count { |s| s.status == "completed" }
    absences  = sessions.count { |s| s.status == "absent" }

    render json: {
      name: current_user.name,
      email: current_user.email,
      phone: current_user.phone,
      google_meet_link: current_user.google_meet_link,
      completed_sessions: completed,
      absent_sessions: absences,
      next_session: next_session_for(current_user)
    }
  end

  private

  def next_session_for(user)
    next_concrete = user.sessions
                        .where(status: :scheduled)
                        .where("scheduled_at >= ?", Time.zone.now)
                        .order(:scheduled_at)
                        .first

    if next_concrete
      return {
        date: next_concrete.scheduled_at.to_date.iso8601,
        time: next_concrete.scheduled_at.strftime("%H:%M"),
        weekday: next_concrete.scheduled_at.strftime("%A").downcase,
        session_type: next_concrete.session_type
      }
    end

    schedules = user.weekly_schedules.to_a
    return nil if schedules.empty?

    weekday_numbers = WeeklySchedule.weekdays
    today = Date.today

    (0..7).each do |offset|
      candidate = today + offset.days
      matching = schedules.find { |s| weekday_numbers[s.weekday] == candidate.wday }
      next unless matching

      return {
        date: candidate.iso8601,
        time: matching.time,
        weekday: matching.weekday,
        session_type: "regular"
      }
    end

    nil
  end
end
