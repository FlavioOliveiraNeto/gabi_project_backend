class Therapists::SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!

  def create
    client = current_user.patients.find(params[:patient_id])
    scheduled_at = Time.zone.parse(params[:scheduled_at].to_s)

    session = client.sessions.build(
      scheduled_at: scheduled_at,
      start_time:   scheduled_at,
      end_time:     scheduled_at + 50.minutes,
      session_type: params[:session_type].presence || :recurring,
      meet_link:    params[:meet_link],
      status:       :scheduled
    )

    if session.save
      render json: session_json(session), status: :created
    else
      render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ArgumentError
    render json: { error: "Tipo de sessão inválido: '#{params[:session_type]}'." }, status: :unprocessable_entity
  end

  def update
    session = client_session(params[:id])
    new_status = params[:status].to_s

    result = case new_status
    when "cancelled"  then session.cancel!
    when "absent"     then session.mark_as_absent!
    else
               return render json: { error: "Status inválido: '#{new_status}'." }, status: :unprocessable_entity
    end

    render json: session_json(session.reload)
  rescue Session::InvalidTransition
    render json: { error: "Transição inválida: de '#{session.status}' para '#{new_status}'." }, status: :unprocessable_entity
  end

  def destroy
    session = client_session(params[:id])
    session.destroy!
    head :no_content
  end

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.therapist?
  end

  def client_session(id)
    Session.joins(:user)
           .where(users: { therapist_id: current_user.id })
           .find(id)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Sessão não encontrada." }, status: :not_found and raise
  end

  def session_json(session)
    {
      id:           session.id,
      scheduled_at: session.scheduled_at&.iso8601,
      start_time:   session.start_time&.iso8601,
      end_time:     session.end_time&.iso8601,
      status:       session.status,
      session_type: session.session_type,
      meet_link:    session.meet_link,
      client: {
        id:    session.user.id,
        name:  session.user.name,
        email: session.user.email
      }
    }
  end
end
