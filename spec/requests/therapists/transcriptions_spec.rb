require "rails_helper"

RSpec.describe "Therapists::Transcriptions", type: :request do
  include_context "autenticado como terapeuta"

  let(:audio) { Rack::Test::UploadedFile.new(StringIO.new("fake-audio"), "audio/m4a", original_filename: "nota.m4a") }

  def post_audio(file = audio)
    post "/therapists/transcription", params: { audio: file }, headers: headers
  end

  it "retorna o texto transcrito" do
    allow(TranscriptionService).to receive(:call).and_return("paciente relatou melhora")

    post_audio

    expect(response).to have_http_status(:ok)
    expect(json_body["text"]).to eq("paciente relatou melhora")
  end

  it "rejeita formatos não suportados" do
    post_audio(Rack::Test::UploadedFile.new(StringIO.new("x"), "application/pdf", original_filename: "a.pdf"))

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejeita requisição sem arquivo" do
    post "/therapists/transcription", params: {}, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejeita áudio acima do limite" do
    allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(21.megabytes)

    post_audio

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "responde 502 quando o provedor falha" do
    allow(TranscriptionService).to receive(:call).and_raise(TranscriptionService::Error, "Não foi possível transcrever o áudio.")

    post_audio

    expect(response).to have_http_status(:bad_gateway)
  end

  it "bloqueia clientes" do
    client = create(:user, :client, therapist: therapist)
    post "/therapists/transcription", params: { audio: audio }, headers: auth_headers_for(client)

    expect(response).to have_http_status(:forbidden)
  end

  it "bloqueia não autenticados" do
    post "/therapists/transcription", params: { audio: audio }

    expect(response).to have_http_status(:unauthorized)
  end
end
