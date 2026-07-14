module Helpers
  module JsonHelper
    # Parseia o body da resposta como JSON com chaves simbolizadas.
    #
    # Retorna: Hash com symbol keys, ex: { error: "Unauthorized" }
    # Use `:error` (símbolo), não `"error"` (string) nos matchers.
    #
    # Exemplo:
    #   expect(json_response[:data][:email]).to eq(patient.email)
    #   expect(json_response).to include(:error)
    #
    def json_response
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError => e
      raise "json_response: body não é JSON válido.\n" \
            "Status: #{response.status}\n" \
            "Body: #{response.body.truncate(500)}\n" \
            "Erro: #{e.message}"
    end

    # Parseia o body da resposta como JSON com chaves string.
    #
    # Retorna: Hash com string keys, ex: { "error" => "Unauthorized" }
    #
    def json_body
      JSON.parse(response.body)
    rescue JSON::ParserError
      {}
    end

    # Acessa um atributo aninhado com sintaxe de dig usando symbol keys.
    #
    # Exemplo:
    #   expect(json_dig(:data, :attributes, :name)).to eq("Maria")
    #
    def json_dig(*keys)
      json_response.dig(*keys)
    end
  end
end

RSpec.configure do |config|
  config.include Helpers::JsonHelper
end
