# frozen_string_literal: true

class Therapists::SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!

  # POST /therapists/sessions
  def create
    client = current_user.patients.find(params[:client_id])

    session = client.sessions.build(
      start_time:   params[:start_time],
      end_time:     params[:end_time],
      session_type: params[:session_type].presence || :recurring,
      meet_link:    params[:meet_link],
      status:       :scheduled
    )

    if session.save
      render json: session_json(session), status: :created
    else
      render json: { errors: session.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /therapists/sessions/:id
  def update
    session = client_session(params[:id])
    new_status = params[:status].to_s

    result = case new_status
             when "cancelled"  then session.cancel!
             when "missed"     then session.mark_as_missed!
             else
               return render json: { error: "Status inválido: '#{new_status}'." }, status: :unprocessable_entity
             end

    render json: session_json(session.reload)
  rescue Session::InvalidTransition => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /therapists/sessions/:id
  def destroy
    session = client_session(params[:id])
    session.cancel!
    head :no_content
  rescue Session::InvalidTransition => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.therapist?
  end

  # Busca uma sessão cujo usuário (cliente) pertence à terapeuta atual
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
