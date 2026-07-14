class ScheduleChangeService
  Error = Class.new(StandardError)

  def initialize(patient:, therapist:, effective_from:, schedule_type:, schedule_params: {})
    @patient         = patient
    @therapist       = therapist
    @effective_from  = effective_from.to_date
    @schedule_type   = schedule_type
    @schedule_params = schedule_params
  end

  def call
    case @schedule_type
    when "regular"
      transition_to_regular!
    when "extra"
      transition_to_extra!
    end

    @patient
  end

  private

  def transition_to_regular!
    validate_regular_params!
    close_active_schedules!
    cancel_scheduled_sessions_from!(@effective_from)
    create_new_weekly_schedules!
    SessionGeneratorService.new(@therapist).generate_for_patient_from(@patient, from: @effective_from)
  end

  def transition_to_extra!
    close_active_schedules!
    cancel_scheduled_sessions_from!(@effective_from)
  end

  def close_active_schedules!
    @patient.weekly_schedules
            .where("effective_from < ?", @effective_from)
            .where("effective_until IS NULL OR effective_until >= ?", @effective_from)
            .update_all(effective_until: @effective_from - 1.day)
  end

  def cancel_scheduled_sessions_from!(date)
    @patient.sessions
            .where(session_type: :recurring, status: :scheduled)
            .where("scheduled_at >= ?", date.beginning_of_day)
            .update_all(
              status:     Session.statuses[:cancelled],
              updated_at: Time.current
            )
  end

  def create_new_weekly_schedules!
    weekdays          = Array(@schedule_params[:weekdays]).compact
    sessions_per_week = @schedule_params[:sessions_per_week].to_i
    session_time      = @schedule_params[:session_time].to_s.strip

    weekdays.each do |weekday|
      @patient.weekly_schedules.create!(
        weekday:           weekday,
        sessions_per_week: sessions_per_week,
        time:              session_time,
        effective_from:    @effective_from
      )
    rescue ArgumentError
      record = @patient.weekly_schedules.build
      record.errors.add(:weekday, :invalid)
      raise ActiveRecord::RecordInvalid.new(record)
    end
  end

  def validate_regular_params!
    weekdays     = Array(@schedule_params[:weekdays]).compact
    session_time = @schedule_params[:session_time].to_s.strip

    raise Error, "Informe ao menos um dia da semana." if weekdays.empty?
    raise Error, "Horário inválido ou não informado." if session_time.blank?
  end
end
