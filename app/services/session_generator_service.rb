class SessionGeneratorService
  def initialize(therapist)
    @therapist = therapist
  end

  # Chamado pelo WeeklySessionGenerationJob — gera mês atual e próximo
  # respeitando effective_from e effective_until de cada schedule.
  def generate_for_current_and_next_month
    @therapist.patients.includes(:weekly_schedules).find_each do |patient|
      generate_for_patient(patient)
    end
  end

  # Gera sessões para o paciente dentro da janela (mês atual + próximo),
  # limitando cada schedule ao seu próprio período de vigência.
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

  # Gera sessões a partir de uma data específica (effective_from de uma nova agenda).
  # Chamado pelo ScheduleChangeService ao criar nova agenda regular.
  def generate_for_patient_from(patient, from:)
    from_date  = from.to_date
    window_end = Date.current.next_month.end_of_month

    patient.weekly_schedules.overlapping(from_date, window_end).each do |schedule|
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
