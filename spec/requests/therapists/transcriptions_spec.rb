require "rails_helper"

RSpec.describe "Therapists::Transcriptions", type: :request do
  include_context "autenticado como terapeuta"

  # Cabeçalho mínimo de um m4a real (caixa ftyp M4A): o controller confere os bytes.
  let(:m4a_bytes) { "\x00\x00\x00\x20ftypM4A \x00\x00\x02\x00M4A isommp42".b + ("\x00" * 16) }

  let(:audio) { Rack::Test::UploadedFile.new(StringIO.new(m4a_bytes), "audio/m4a", original_filename: "nota.m4a") }

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

  it "rejeita arquivo que declara áudio mas não é (Content-Type forjado)" do
    fake = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n"), "audio/m4a", original_filename: "nota.m4a")
    expect(TranscriptionService).not_to receive(:call)

    post_audio(fake)

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
