class Therapists::SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!

  ALLOWED_SESSION_TYPES = %w[regular extra].freeze

  def create
    patient = current_user.patients.find(params[:patient_id])

    requested_type = params[:session_type].to_s
    unless requested_type.empty? || ALLOWED_SESSION_TYPES.include?(requested_type)
      render json: { error: "Tipo de sessão inválido. Use 'regular' ou 'extra'." }, status: :unprocessable_entity
      return
    end

    session = patient.sessions.build(
      scheduled_at: params[:scheduled_at],
      status: :scheduled,
      session_type: requested_type.presence || :regular
    )

    if session.save
      render json: session, status: :created
    else
      render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    session = Session.joins(:user)
                     .where(users: { therapist_id: current_user.id })
                     .find(params[:id])

    if session.update(status: params[:status])
      render json: session
    else
      render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.therapist?
  end
end