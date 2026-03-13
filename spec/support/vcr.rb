require "vcr"

VCR.configure do |config|
  # Cassettes gravados em spec/cassettes/
  config.cassette_library_dir = "spec/cassettes"

  # Integração com WebMock (evita conflito entre as duas gems)
  config.hook_into :webmock

  # Grava novas interações, reproduz as já gravadas
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method uri]
  }

  # Permite que o RSpec use a tag :vcr para ativar cassettes automaticamente
  config.configure_rspec_metadata!

  # Filtra dados sensíveis de variáveis de ambiente para não gravar em cassettes
  %w[
    SECRET_KEY_BASE
    DEVISE_JWT_SECRET_KEY
    DATABASE_URL
    SMTP_PASSWORD
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
  ].each do |env_var|
    config.filter_sensitive_data("<#{env_var}>") { ENV[env_var] }
  end
end
