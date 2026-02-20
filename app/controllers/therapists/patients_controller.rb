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
    patient.password = Devise.friendly_token.first(8)

    ActiveRecord::Base.transaction do
      if patient.save
        build_weekly_schedules(patient)
        render json: patient_json(patient), status: :created
      else
        render json: { errors: patient.errors.full_messages }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  end

  def update
    ActiveRecord::Base.transaction do
      if @patient.update(patient_params)
        if params[:weekdays].present?
          @patient.weekly_schedules.destroy_all
          build_weekly_schedules(@patient)
        end
        @patient.reload
        render json: patient_json(@patient)
      else
        render json: { errors: @patient.errors.full_messages }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
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

  def patient_json(patient)
    schedules = patient.weekly_schedules
    {
      id: patient.id,
      name: patient.name,
      email: patient.email,
      google_meet_link: patient.google_meet_link,
      created_at: patient.created_at,
      sessions_per_week: schedules.first&.sessions_per_week || 0,
      session_days: schedules.map(&:weekday),
      session_time: schedules.first&.time,
      completed_sessions: patient.sessions.count { |s| s.status == "completed" },
      absent_sessions: patient.sessions.count { |s| s.status == "absent" },
      clinical_notes: patient.clinical_notes.sort_by(&:created_at).reverse.map do |n|
        { id: n.id, content: n.content, date: n.date, created_at: n.created_at }
      end
    }
  end
end
