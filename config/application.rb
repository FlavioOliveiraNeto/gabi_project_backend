require_relative "boot"
require_relative "../lib/middleware/jwt_cookie_to_header"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module GabiProjectBackend
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true

    # `middleware` is ignored because lib/middleware/jwt_cookie_to_header.rb is
    # manually required above (line 2) and defines a top-level constant, not the
    # Zeitwerk-expected Middleware::JwtCookieToHeader. Without this, eager_load
    # (CI/production) raises "uninitialized constant Middleware::JwtCookieToHeader".
    config.autoload_lib(ignore: %w[assets tasks middleware])

    config.middleware.use Rack::Attack

    config.middleware.use ActionDispatch::Cookies

    config.middleware.use JwtCookieToHeader

    config.time_zone = "Brasilia"
    config.active_record.default_timezone = :local
    config.beginning_of_week = :sunday

    config.generators.system_tests = nil

    config.active_record.encryption.primary_key        = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key  = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
  end
end
