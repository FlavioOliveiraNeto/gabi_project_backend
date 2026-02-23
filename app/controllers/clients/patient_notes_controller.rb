class Clients::PatientNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_client!

  def index
    render json: current_user.patient_notes
  end

  def create
    note = current_user.patient_notes.build(note_params)

    if note.save
      render json: note, status: :created
    else
      render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    note = current_user.patient_notes.find(params[:id])
    note.destroy
    head :no_content
  end

  private

  def ensure_client!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.client?
  end

  def note_params
    params.permit(:content)
  end
end