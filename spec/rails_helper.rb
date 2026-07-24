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

ENV["AR_ENCRYPTION_PRIMARY_KEY"]         ||= "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1"
ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]   ||= "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2"
ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3"

require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = []
  config.use_transactional_fixtures = false

  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!

  config.filter_run_when_matching :focus

  config.order = :random

  config.example_status_persistence_file_path = ".rspec_status"

  config.around(:each) do |example|
    Time.use_zone("America/Sao_Paulo") { example.run }
  end

  config.include ActiveSupport::Testing::TimeHelpers

  config.include Helpers::AuthenticationHelper, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :request

  config.before(:each) do
    Rack::Attack.reset! rescue nil
  end
end
