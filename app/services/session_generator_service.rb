require "set"

class SessionGeneratorService
  SESSION_DURATION = 50.minutes

  attr_reader :conflicts

  def initialize(therapist)
    @therapist     = therapist
    @conflicts     = []
    @conflict_keys = Set.new
  end

  def generate_for_current_and_next_month
    @therapist.patients.includes(:weekly_schedules).find_each do |patient|
      generate_for_patient(patient)
    end
  end

  def generate_for_patient(patient)
    window_start = Date.current.beginning_of_month
    window_end   = Date.current.next_month.end_of_month

    patient.weekly_schedules.overlapping(window_start, window_end).each do |schedule|
      sched_start = [ window_start, schedule.effective_from, Date.current ].max
      sched_end   = schedule.effective_until ? [ window_end, schedule.effective_until ].min : window_end

      next if sched_start > sched_end

      generate_for_schedule(patient, schedule, sched_start, sched_end)
    end
  end

  def generate_for_patient_from(patient, from:)
    from_date  = from.to_date
    window_end = Date.current.next_month.end_of_month

    patient.weekly_schedules
           .where("effective_from <= ?", window_end)
           .where("effective_until IS NULL OR effective_until >= ?", from_date)
           .each do |schedule|
      sched_start = [ from_date, schedule.effective_from ].max
      sched_end   = schedule.effective_until ? [ window_end, schedule.effective_until ].min : window_end

      next if sched_start > sched_end

      generate_for_schedule(patient, schedule, sched_start, sched_end)
    end
  end

  private

  def generate_for_schedule(patient, schedule, start_date, end_date)
    return if schedule.time.blank?

    hour, min   = schedule.time.split(":")
    weekday_int = schedule.weekday_before_type_cast

    (start_date..end_date).each do |date|
      next unless date.wday == weekday_int
      next if date < Date.current

      datetime = Time.zone.local(date.year, date.month, date.day, hour.to_i, min.to_i)

      patient.sessions.find_or_create_by!(scheduled_at: datetime, session_type: :recurring) do |session|
        session.status     = :scheduled
        session.start_time = datetime
        session.end_time   = datetime + SESSION_DURATION
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      record_conflict(patient, schedule, datetime, e)
    end
  end

  def record_conflict(patient, schedule, datetime, error)
    key = [ patient.id, schedule.weekday, schedule.time ]
    return unless @conflict_keys.add?(key)

    Rails.logger.warn(
      "[SessionGenerator] Conflito para paciente ##{patient.id} em #{datetime.iso8601}: #{error.message}"
    )

    @conflicts << {
      patient_id:   patient.id,
      weekday:      schedule.weekday,
      time:         schedule.time,
      scheduled_at: datetime,
      reason:       conflict_reason(error)
    }
  end

  def conflict_reason(error)
    if error.is_a?(ActiveRecord::RecordInvalid)
      messages = error.record.errors.full_messages_for(:start_time)
      return messages.to_sentence if messages.any?
    end

    "conflita com outra sessão já agendada"
  end
end
