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
      when "weekly"
        create_weekly_sessions(patient)
      when "single"
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

      when "weekly"
        @patient.sessions.where(session_type: :regular).destroy_all

        @patient.weekly_schedules.destroy_all

        build_weekly_schedules(@patient)

        create_weekly_sessions(@patient)
      when "single"
        @patient.weekly_schedules.destroy_all

        @patient.sessions.where(session_type: :regular).destroy_all

        create_single_session(@patient)
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

  def next_weekday_time(weekday_str, time_str)
    return nil unless time_str.present?

    weekdays = {
      "sunday" => 0, "monday" => 1, "tuesday" => 2, "wednesday" => 3,
      "thursday" => 4, "friday" => 5, "saturday" => 6
    }

    target_wday = weekdays[weekday_str.to_s.downcase]

    return nil if target_wday.nil?

    now = Time.zone.now
    hour, min = time_str.split(":").map(&:to_i)
    date = now.to_date
    days_ahead = (target_wday - date.wday) % 7
    days_ahead = 7 if days_ahead == 0
    next_date = date + days_ahead
    Time.zone.local(next_date.year, next_date.month, next_date.day, hour, min)
  end

  def create_weekly_sessions(patient)
    return unless params[:weekdays].is_a?(Array)
    return unless params[:session_time].present?

    params[:weekdays].each do |weekday|
      scheduled_at = next_weekday_time(weekday, params[:session_time])
      next unless scheduled_at

      patient.sessions.create!(
        scheduled_at: scheduled_at,
        status: :scheduled,
        session_type: :regular
      )
    end
  end

  def create_single_session(patient)
    return unless params[:single_date].present?
    return unless params[:single_time].present?

    scheduled_at = Time.zone.parse(
      "#{params[:single_date]} #{params[:single_time]}"
    )

    return unless scheduled_at

    patient.sessions.create!(
      scheduled_at: scheduled_at,
      status: :scheduled,
      session_type: :extra
    )
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
      completed_sessions: patient.sessions.where(status: :completed).count,
      absent_sessions: patient.sessions.where(status: :absent).count,
      clinical_notes: patient.clinical_notes.order(created_at: :desc).map do |n|
        { id: n.id, content: n.content, date: n.date, created_at: n.created_at }
      end
    }
  end
end
