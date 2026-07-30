require_relative "boot"
require_relative "../lib/middleware/jwt_cookie_to_header"
require_relative "../lib/encryption_config"

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

    config.autoload_lib(ignore: %w[assets tasks middleware encryption_config.rb])

    config.middleware.use Rack::Attack

    config.middleware.use ActionDispatch::Cookies

    config.middleware.use JwtCookieToHeader

    config.time_zone = "Brasilia"
    config.active_record.default_timezone = :local
    config.beginning_of_week = :sunday

    config.generators.system_tests = nil

    encryption_keys = EncryptionConfig.fetch!(env: Rails.env)

    config.active_record.encryption.primary_key          = encryption_keys[:primary_key]
    config.active_record.encryption.deterministic_key    = encryption_keys[:deterministic_key]
    config.active_record.encryption.key_derivation_salt  = encryption_keys[:key_derivation_salt]
  end
end
