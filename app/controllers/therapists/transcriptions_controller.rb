class Therapists::TranscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!

  MAX_BYTES = 20.megabytes
  ALLOWED_TYPES = %w[audio/m4a audio/mp4 audio/x-m4a audio/aac audio/mpeg audio/wav audio/webm audio/ogg].freeze

  def create
    audio = params[:audio]
    return render json: { error: "Envie um arquivo de áudio." }, status: :unprocessable_entity unless audio.respond_to?(:read)

    content_type = audio.content_type.to_s.split(";").first
    unless ALLOWED_TYPES.include?(content_type)
      return render json: { error: "Formato de áudio não suportado." }, status: :unprocessable_entity
    end

    if audio.size > MAX_BYTES
      return render json: { error: "Áudio muito longo (máx. 20 MB)." }, status: :unprocessable_entity
    end

    render json: { text: TranscriptionService.call(audio, content_type) }
  rescue TranscriptionService::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito." }, status: :forbidden unless current_user.therapist?
  end
end
