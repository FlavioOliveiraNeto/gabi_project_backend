# SimpleCov deve ser iniciado ANTES de qualquer require da aplicação.
# O `require: false` no Gemfile garante que só roda quando requerido aqui.
require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = "coverage/lcov.info"
end

SimpleCov.start "rails" do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ])

  # O threshold só é aplicado quando há specs reais.
  # Em --dry-run ou CI de estrutura (sem código de produção ainda) o threshold
  # seria sempre violado, então desabilitamos com a env var SIMPLECOV_NO_MINIMUM.
  minimum_coverage 90 unless ENV["SIMPLECOV_NO_MINIMUM"] || ARGV.include?("--dry-run")

  add_group "Models",      "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services",    "app/services"
  add_group "Jobs",        "app/jobs"
  add_group "Mailers",     "app/mailers"
  add_group "Serializers", "app/serializers"
  add_group "Policies",    "app/policies"
  add_group "Lib",         "lib"

  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/db/"
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"

# Chaves de criptografia do Active Record para o ambiente de teste.
# Devem ser definidas ANTES do boot do Rails para que o config/application.rb
# as leia corretamente via ENV.
ENV["AR_ENCRYPTION_PRIMARY_KEY"]         ||= "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1"
ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]   ||= "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2"
ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3"

require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

# Carrega todos os arquivos de suporte em spec/support/**/*.rb
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Desativa fixtures — usamos factories exclusivamente
  config.fixture_paths = []
  config.use_transactional_fixtures = false

  # Infere o tipo do spec pelo local do arquivo
  config.infer_spec_type_from_file_location!

  # Filtra linhas de gems Rails nos backtraces
  config.filter_rails_from_backtrace!

  # Focus: executa apenas exemplos marcados com :focus
  config.filter_run_when_matching :focus

  # Ordem aleatória para detectar dependências entre specs
  config.order = :random

  # Persiste status entre execuções (suporta --only-failures e --next-failure)
  config.example_status_persistence_file_path = ".rspec_status"

  # Timezone fixo para todo o sistema — America/Sao_Paulo
  # Garante que testes de horário (sessões, jobs, bloqueios) sejam deterministas
  config.around(:each) do |example|
    Time.use_zone("America/Sao_Paulo") { example.run }
  end

  config.include ActiveSupport::Testing::TimeHelpers

  # Helpers incluídos por tipo de spec
  # JsonHelper é incluído globalmente no próprio arquivo de support
  # FactoryBot é incluído globalmente no próprio arquivo de support
  config.include Helpers::AuthenticationHelper, type: :request

  # Reseta o cache do Rack::Attack antes de cada teste para evitar que
  # tentativas acumuladas de autenticação (login real feito pelos helpers de
  # CSRF/cookie) disparem o rate limiting entre exemplos.
  config.before(:each) do
    Rack::Attack.reset! rescue nil
  end
end
