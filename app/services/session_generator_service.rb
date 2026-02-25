class SessionGeneratorService
  def initialize(therapist)
    @therapist = therapist
  end

  def generate_for_current_and_next_month
    @therapist.patients.includes(:weekly_schedules).find_each do |patient|
      generate_for_patient(patient)
    end
  end

  def generate_for_patient(patient)
    patient.weekly_schedules.each do |schedule|
      generate_for_schedule(patient, schedule, Date.current.beginning_of_month, Date.current.end_of_month)
      generate_for_schedule(patient, schedule, Date.current.next_month.beginning_of_month, Date.current.next_month.end_of_month)
    end
  end

  private

  def generate_for_schedule(patient, schedule, start_date, end_date)
    return if schedule.time.blank?

    hour, min = schedule.time.split(":")
    weekday_int = schedule.weekday_before_type_cast

    (start_date..end_date).each do |date|
      next unless date.wday == weekday_int

      next if date < Date.current

      datetime = Time.zone.local(
        date.year,
        date.month,
        date.day,
        hour.to_i,
        min.to_i
      )

      patient.sessions.find_or_create_by!(scheduled_at: datetime, session_type: :regular) do |session|
        session.status = :scheduled
      end
    rescue ActiveRecord::RecordInvalid => e
      # Conflito de horário com sessão de outro paciente — loga e pula.
      # A terapeuta deve resolver manualmente via dashboard.
      Rails.logger.warn "[SessionGenerator] Conflito ignorado para paciente ##{patient.id} em #{datetime}: #{e.message}"
    end
  end
end