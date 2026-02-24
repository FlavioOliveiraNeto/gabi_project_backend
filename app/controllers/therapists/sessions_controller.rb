class Therapists::SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!

  ALLOWED_SESSION_TYPES = %w[regular extra].freeze

  ALLOWED_STATUSES = %w[scheduled completed absent cancelled].freeze

  # Transições de status permitidas por estado atual
  ALLOWED_TRANSITIONS = {
    "scheduled" => %w[completed absent cancelled],
    "completed" => %w[absent cancelled],
    "absent"    => %w[cancelled],
    "cancelled" => []
  }.freeze

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

    new_status = params[:status].to_s

    unless ALLOWED_STATUSES.include?(new_status)
      render json: { error: "Status inválido. Use: #{ALLOWED_STATUSES.join(', ')}." }, status: :unprocessable_entity
      return
    end

    allowed_next = ALLOWED_TRANSITIONS[session.status]
    unless allowed_next.include?(new_status)
      render json: {
        error: "Transição inválida: sessão '#{session.status}' não pode ser alterada para '#{new_status}'."
      }, status: :unprocessable_entity
      return
    end

    if session.update(status: new_status)
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