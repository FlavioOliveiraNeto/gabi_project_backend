class Therapists::PatientsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!
  before_action :set_patient, only: %i[show update destroy]

  def index
    patients = current_user.patients.includes(:clinical_notes, :sessions, :weekly_schedules)
    render json: patients.map { |p| patient_json(p) }
  end

  def show
    render json: patient_json(@patient)
  end

  def create
    patient = current_user.patients.build(patient_params)
    patient.role = :client
    generated_password = Devise.friendly_token.first(8)
    patient.password = generated_password
    patient.must_change_password = true

    ActiveRecord::Base.transaction do
      patient.save!

      build_weekly_schedules(patient)

      case params[:schedule_type]
      when "regular"
        SessionGeneratorService.new(current_user).generate_for_patient(patient)
      when "extra"
        create_single_session(patient)
      end

      render json: patient_json(patient).merge({ generated_password: generated_password }), status: :created
    end

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def update
    ActiveRecord::Base.transaction do
      @patient.update!(patient_params)

      case params[:schedule_type]
      when "regular"
        @patient.sessions
                .where(session_type: :regular)
                .where("scheduled_at >= ?", Time.current)
                .update_all(status: Session.statuses[:cancelled])

        @patient.weekly_schedules.destroy_all

        build_weekly_schedules(@patient)

        SessionGeneratorService.new(current_user).generate_for_patient(@patient)

      when "extra"
        @patient.weekly_schedules.destroy_all

        @patient.sessions
                .where(session_type: :regular)
                .where("scheduled_at >= ?", Time.current)
                .update_all(status: Session.statuses[:cancelled])

        if params[:session_id].present?
          # Atualiza sessão extra existente (edição)
          update_extra_session(@patient)
        else
          # Cria nova sessão extra (troca de regular → extra)
          create_single_session(@patient)
        end
      end

      @patient.reload
      render json: patient_json(@patient)
    end

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    @patient.destroy
    head :no_content
  end

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.therapist?
  end

  def set_patient
    @patient = current_user.patients.includes(:clinical_notes, :sessions, :weekly_schedules).find(params[:id])
  end

  def patient_params
    params.permit(:name, :email, :google_meet_link)
  end

  def build_weekly_schedules(patient)
    return unless params[:weekdays].is_a?(Array) && params[:weekdays].any?

    sessions_per_week = params[:sessions_per_week].to_i
    session_time = params[:session_time].presence

    params[:weekdays].each do |weekday|
      patient.weekly_schedules.create!(
        weekday: weekday,
        sessions_per_week: sessions_per_week,
        time: session_time
      )
    end
  end

  def create_single_session(patient)
    return unless params[:single_date].present?
    return unless params[:single_time].present?

    scheduled_at = Time.zone.parse("#{params[:single_date]} #{params[:single_time]}")
    return unless scheduled_at

    patient.sessions.create!(
      scheduled_at: scheduled_at,
      status: :scheduled,
      session_type: :extra
    )
  end

  # Atualiza uma sessão extra existente identificada por params[:session_id].
  # Nunca cria uma nova sessão — apenas altera o horário da existente.
  def update_extra_session(patient)
    return unless params[:single_date].present? && params[:single_time].present?

    session = patient.sessions
                     .where(session_type: :extra)
                     .find_by(id: params[:session_id])

    return unless session

    scheduled_at = Time.zone.parse("#{params[:single_date]} #{params[:single_time]}")
    return unless scheduled_at

    session.update!(scheduled_at: scheduled_at)
  end

  def patient_json(patient)
    schedules    = patient.weekly_schedules.to_a
    all_sessions = patient.sessions.to_a
    by_status    = all_sessions.group_by(&:status)
    extra_sessions = all_sessions
                       .select { |s| s.session_type == "extra" }
                       .sort_by(&:scheduled_at)

    schedule_type = schedules.any? ? "regular" : "extra"

    {
      id: patient.id,
      name: patient.name,
      email: patient.email,
      google_meet_link: patient.google_meet_link,
      created_at: patient.created_at,
      schedule_type: schedule_type,
      sessions_per_week: schedules.first&.sessions_per_week || 0,
      session_days: schedules.map(&:weekday),
      session_time: schedules.first&.time,
      completed_sessions: (by_status["completed"] || []).count,
      absent_sessions: (by_status["absent"] || []).count,
      extra_sessions: extra_sessions.map do |s|
        local_time = s.scheduled_at.in_time_zone(Time.zone)
        { id: s.id, date: local_time.to_date.iso8601, time: local_time.strftime("%H:%M"), status: s.status }
      end,
      clinical_notes: patient.clinical_notes.to_a
                             .select { |n| n.therapist_id == current_user.id }
                             .sort_by(&:created_at)
                             .reverse
                             .map { |n| { id: n.id, content: n.content, date: n.date, created_at: n.created_at } }
    }
  end
end
