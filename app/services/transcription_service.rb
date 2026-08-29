require "net/http"

# Speech-to-text via Deepgram (nova-3, pt-BR).
#
# ponytail: Deepgram only. Its free tier ($200 credit, ~45k min) outlives and
# out-sizes Google STT's 60 min/month, so the fallback the spec asked for buys
# nothing today. If credits run out, add a Google branch in `.call`.
class TranscriptionService
  Error = Class.new(StandardError)

  ENDPOINT = URI("https://api.deepgram.com/v1/listen?model=nova-3&language=pt-BR&smart_format=true&punctuate=true")

  def self.api_key
    ENV["DEEPGRAM_API_KEY"].presence || Rails.application.credentials.deepgram_api_key
  end

  # audio: an IO (uploaded file). content_type: e.g. "audio/m4a".
  # Returns the transcript String (may be empty for silence).
  def self.call(audio, content_type)
    key = api_key
    raise Error, "Transcrição não configurada." if key.blank?

    request = Net::HTTP::Post.new(ENDPOINT)
    request["Authorization"] = "Token #{key}"
    request["Content-Type"] = content_type
    request.body = audio.read

    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, read_timeout: 120) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("Deepgram #{response.code}: #{response.body&.truncate(500)}")
      raise Error, "Não foi possível transcrever o áudio."
    end

    JSON.parse(response.body)
        .dig("results", "channels", 0, "alternatives", 0, "transcript")
        .to_s
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.error("Deepgram falhou: #{e.class}: #{e.message}")
    raise Error, "Não foi possível transcrever o áudio."
  end
end
