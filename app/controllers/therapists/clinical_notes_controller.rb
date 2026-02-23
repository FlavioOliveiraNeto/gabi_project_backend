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

  def show
    unless current_user.therapist?
      render json: { error: "Acesso restrito." }, status: :forbidden
      return
    end

    @note = ClinicalNote.find_by(id: params[:id])
    unless @note && @note.user.therapist_id == current_user.id
      render json: { error: "Nota não encontrada ou acesso negado." }, status: :not_found
      return
    end

    render json: @note.as_json(only: %i[id content date created_at])
  end

  def update
    unless current_user.therapist?
      render json: { error: "Acesso restrito." }, status: :forbidden
      return
    end

    @note = ClinicalNote.find_by(id: params[:id])
    unless @note && @note.user.therapist_id == current_user.id
      render json: { error: "Nota não encontrada ou acesso negado." }, status: :not_found
      return
    end

    if @note.update(content: params[:content])
      render json: @note.as_json(only: %i[id content date created_at])
    else
      render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    unless current_user.therapist?
      render json: { error: "Acesso restrito." }, status: :forbidden
      return
    end

    @note = ClinicalNote.find_by(id: params[:id])
    unless @note && @note.user.therapist_id == current_user.id
      render json: { error: "Nota não encontrada ou acesso negado." }, status: :not_found
      return
    end

    @note.destroy
    head :no_content
  end
end
