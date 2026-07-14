class Therapists::ClinicalNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!
  before_action :set_patient
  before_action :set_note, only: %i[show update destroy]

  def index
    render json: @patient.clinical_notes
                         .where(therapist: current_user)
                         .order(created_at: :desc)
                         .as_json(only: %i[id content date created_at])
  end

  def create
    session = @patient.sessions.find_by(id: params[:session_id])
    return render json: { error: "Sessão não encontrada." }, status: :not_found unless session

    note = @patient.clinical_notes.build(
      session: session,
      content: params[:content],
      date: session.start_time,
      therapist: current_user
    )

    if note.save
      render json: note.as_json(only: %i[id content date created_at]), status: :created
    else
      render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: @note.as_json(only: %i[id content date created_at])
  end

  def update
    if @note.update(content: params[:content])
      render json: @note.as_json(only: %i[id content date created_at])
    else
      render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @note.destroy
    head :no_content
  end

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.therapist?
  end

  def set_patient
    @patient = current_user.patients.find_by(id: params[:patient_id])
    render json: { error: "Paciente não encontrado." }, status: :not_found unless @patient
  end

  def set_note
    @note = @patient.clinical_notes.where(therapist: current_user).find_by(id: params[:id])
    render json: { error: "Nota não encontrada." }, status: :not_found unless @note
  end
end
