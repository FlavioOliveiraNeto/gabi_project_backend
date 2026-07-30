class Clients::PatientNotesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_client!
  before_action :enforce_password_change!

  def index
    notes = current_user.patient_notes
                        .order(created_at: :desc)
                        .limit(page_limit)
                        .offset(page_offset)

    render json: notes.map { |note| note_json(note) }
  end

  def create
    note = current_user.patient_notes.build(note_params)

    if note.save
      render json: note_json(note), status: :created
    else
      render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    note = current_user.patient_notes.find(params[:id])
    if note.update(note_params)
      render json: note_json(note)
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

  def note_json(note)
    {
      id:         note.id,
      content:    note.content,
      created_at: note.created_at,
      updated_at: note.updated_at
    }
  end
end
