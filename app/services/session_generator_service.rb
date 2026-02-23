class SessionGeneratorService
  def initialize(therapist)
    @therapist = therapist
  end

  def generate_for_next_month
    @therapist.patients.includes(:weekly_schedules).find_each do |patient|
      patient.weekly_schedules.each do |schedule|
        generate_for_schedule(patient, schedule)
      end
    end
  end

  private

  def generate_for_schedule(patient, schedule)
    start_date = Date.current
    end_date   = start_date + 1.month

    hour, min = schedule.time.split(":")

    weekday_int = schedule.weekday_before_type_cast

    (start_date..end_date).each do |date|
      next unless date.wday == weekday_int

      datetime = Time.zone.local(
        date.year,
        date.month,
        date.day,
        hour.to_i,
        min.to_i
      )

      patient.sessions.find_or_create_by!(scheduled_at: datetime) do |session|
        session.status = :scheduled
      end
    end
  end
end