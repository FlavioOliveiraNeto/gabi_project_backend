require 'spec_helper'
ENV['RAILS_ENV'] = 'test'

# Chaves de criptografia do Active Record para o ambiente de teste.
# Devem ser definidas ANTES do boot do Rails para que o config/application.rb
# as leia corretamente via ENV.
ENV['AR_ENCRYPTION_PRIMARY_KEY']         ||= 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1'
ENV['AR_ENCRYPTION_DETERMINISTIC_KEY']   ||= 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2'
ENV['AR_ENCRYPTION_KEY_DERIVATION_SALT'] ||= 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3'

require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]

  config.include FactoryBot::Syntax::Methods
  config.include AuthenticationHelpers, type: :request
  config.include ActiveSupport::Testing::TimeHelpers

  config.include_context "autenticado como terapeuta", :as_therapist
  config.include_context "autenticado como cliente", :as_client

  config.infer_spec_type_from_file_location!
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    DatabaseCleaner.allow_remote_database_url = true
    DatabaseCleaner.clean_with(:truncation)
  end

  # Reseta o cache do Rack::Attack antes de cada teste para evitar que
  # tentativas acumuladas de autenticação disparem o rate limiting.
  config.before(:each) do
    Rack::Attack.reset! rescue nil
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
