# app/services/schedule_change_service.rb
#
# Responsável por coordenar mudanças de agenda de um paciente respeitando
# a data de vigência (effective_from). Nunca destrói histórico.
#
# Invariantes garantidas:
#   - Sessões antes de effective_from permanecem intactas
#   - WeeklySchedules antigos são fechados (effective_until), nunca destruídos
#   - Novas sessões são geradas somente a partir de effective_from
#   - Toda operação é atômica (transaction deve ser gerenciada externamente)
#
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

  # --- Transições ---

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
    # Criação/atualização da sessão extra é responsabilidade do controller —
    # é uma operação simples de CRUD, não uma regra de agenda.
  end

  # --- Operações ---

  # Fecha todos os schedules que estão ativos no momento em que a nova agenda entra em vigor.
  # Define effective_until = effective_from - 1 dia.
  # Usa update_all intencionalmente: WeeklySchedule não tem callbacks relevantes
  # e a operação é de encerramento administrativo em lote.
  def close_active_schedules!
    @patient.weekly_schedules
            .where("effective_from < ?", @effective_from)
            .where("effective_until IS NULL OR effective_until >= ?", @effective_from)
            .update_all(effective_until: @effective_from - 1.day)
  end

  # Cancela apenas sessões regulares com status :scheduled a partir da data de vigência.
  # Sessões completed/absent/cancelled não são alteradas.
  # Sessões anteriores a effective_from NÃO são tocadas.
  def cancel_scheduled_sessions_from!(date)
    @patient.sessions
            .where(session_type: :regular, status: :scheduled)
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
    end
  end

  # --- Validações ---

  def validate_regular_params!
    weekdays     = Array(@schedule_params[:weekdays]).compact
    session_time = @schedule_params[:session_time].to_s.strip

    raise Error, "Informe ao menos um dia da semana." if weekdays.empty?
    raise Error, "Horário inválido ou não informado." if session_time.blank?
  end
end
