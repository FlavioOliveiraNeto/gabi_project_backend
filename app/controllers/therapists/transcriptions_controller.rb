require "marcel"

class Therapists::TranscriptionsController < Therapists::BaseController
  MAX_BYTES = 20.megabytes
  ALLOWED_TYPES = %w[audio/m4a audio/mp4 audio/x-m4a audio/aac audio/mpeg audio/wav audio/webm audio/ogg].freeze

  # O que os magic bytes de fato revelam. O container conta, não o codec: o
  # MediaRecorder grava webm (Marcel: matroska) ou mp4 (Marcel: video/mp4).
  # ponytail: AAC cru (ADTS) não tem assinatura reconhecível e cai fora; nenhum
  # cliente nosso grava assim (nativo = m4a).
  SNIFFED_TYPES = %w[
    audio/mp4 video/mp4 video/quicktime audio/mpeg audio/x-wav audio/wav audio/vnd.wave
    application/x-matroska video/webm audio/webm audio/ogg
  ].freeze

  def create
    audio = params[:audio]
    return render json: { error: "Envie um arquivo de áudio." }, status: :unprocessable_entity unless audio.respond_to?(:read)

    content_type = audio.content_type.to_s.split(";").first
    unless ALLOWED_TYPES.include?(content_type)
      return render json: { error: "Formato de áudio não suportado." }, status: :unprocessable_entity
    end

    # Sem `name:` de propósito: com ele o Marcel cai para a extensão quando os
    # bytes não batem, e o header Content-Type já é controlado pelo cliente.
    unless SNIFFED_TYPES.include?(Marcel::MimeType.for(audio.tempfile))
      return render json: { error: "Formato de áudio não suportado." }, status: :unprocessable_entity
    end

    if audio.size > MAX_BYTES
      return render json: { error: "Áudio muito longo (máx. 20 MB)." }, status: :unprocessable_entity
    end

    render json: { text: TranscriptionService.call(audio, content_type) }
  rescue TranscriptionService::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end
end
