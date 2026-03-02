class Therapists::PatientsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!
  before_action :set_patient, only: %i[show update destroy update_schedule]

  def index
    patients = current_user.patients
                           .includes(:clinical_notes, :sessions, :weekly_schedules)

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

      render json: patient_json(patient)
                     .merge(generated_password: generated_password),
             status: :created
    end

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages },
           status: :unprocessable_entity
  end

  def update
    @patient.update!(patient_params)
    render json: patient_json(@patient)

  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages },
           status: :unprocessable_entity
  end

  def destroy
    @patient.destroy
    head :no_content
  end

  def update_schedule
    effective_from = parse_effective_from

    ActiveRecord::Base.transaction do
      case params[:schedule_type].to_s
      when "regular"
        ScheduleChangeService.new(
          patient:         @patient,
          therapist:       current_user,
          effective_from:  effective_from,
          schedule_type:   "regular",
          schedule_params: schedule_params_from_request
        ).call

      when "extra"
        ScheduleChangeService.new(
          patient:        @patient,
          therapist:      current_user,
          effective_from: effective_from,
          schedule_type:  "extra"
        ).call

        if params[:session_id].present?
          update_extra_session(@patient)
        else
          create_single_session(@patient)
        end

      else
        return render json: { error: "Tipo de agenda inválido." },
                      status: :unprocessable_entity
      end

      @patient.reload
      render json: patient_json(@patient)
    end

  rescue ScheduleChangeService::Error => e
    render json: { error: e.message },
           status: :unprocessable_entity
  end

  private

  def ensure_therapist!
    return if current_user.therapist?

    render json: { error: "Acesso restrito." }, status: :forbidden
  end

  def set_patient
    @patient = current_user.patients
                           .includes(:clinical_notes, :sessions, :weekly_schedules)
                           .find(params[:id])
  end

  def patient_params
    params.permit(:name, :email, :google_meet_link)
  end

  def schedule_params_from_request
    {
      weekdays:          params[:weekdays],
      sessions_per_week: params[:sessions_per_week],
      session_time:      params[:session_time]
    }
  end

  def parse_effective_from
    return Date.current unless params[:effective_from].present?

    Date.parse(params[:effective_from].to_s)
  rescue Date::Error
    Date.current
  end

  def create_single_session(patient)
    return unless params[:single_date].present? && params[:single_time].present?

    scheduled_at = Time.zone.parse("#{params[:single_date]} #{params[:single_time]}")
    return unless scheduled_at

    patient.sessions.create!(
      scheduled_at: scheduled_at,
      status:       :scheduled,
      session_type: :extra
    )
  end

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
    active_schedules = patient.weekly_schedules.select(&:active?)
    all_sessions     = patient.sessions.to_a
    by_status        = all_sessions.group_by(&:status)
    extra_sessions   = all_sessions
                         .select { |s| s.session_type == "extra" }
                         .sort_by(&:scheduled_at)

    schedule_type = active_schedules.any? ? "regular" : "extra"

    {
      id:                 patient.id,
      name:               patient.name,
      email:              patient.email,
      google_meet_link:   patient.google_meet_link,
      created_at:         patient.created_at,
      schedule_type:      schedule_type,
      sessions_per_week:  active_schedules.first&.sessions_per_week || 0,
      session_days:       active_schedules.map(&:weekday),
      session_time:       active_schedules.first&.time,
      completed_sessions: (by_status["completed"] || []).count,
      absent_sessions:    (by_status["absent"] || []).count,
      extra_sessions: extra_sessions.map do |s|
        local_time = s.scheduled_at.in_time_zone(Time.zone)
        {
          id:     s.id,
          date:   local_time.to_date.iso8601,
          time:   local_time.strftime("%H:%M"),
          status: s.status
        }
      end,
      clinical_notes: patient.clinical_notes
                             .where(therapist_id: current_user.id)
                             .order(created_at: :desc)
                             .map { |n|
        {
          id:         n.id,
          content:    n.content,
          date:       n.date,
          created_at: n.created_at
        }
      }
    }
  end
end