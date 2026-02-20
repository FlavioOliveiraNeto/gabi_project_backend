class Therapists::ClinicalNotesController < ApplicationController
  before_action :authenticate_user!

  def create
    unless current_user.therapist?
      render json: { error: "Acesso restrito." }, status: :forbidden
      return
    end

    @client = current_user.patients.find_by(id: params[:patient_id])
    unless @client
      render json: { error: "Paciente não encontrado." }, status: :not_found
      return
    end

    @note = @client.clinical_notes.build(
      content: params[:content],
      date: Time.current
    )

    if @note.save
      render json: @note.as_json(only: %i[id content date created_at]), status: :created
    else
      render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
