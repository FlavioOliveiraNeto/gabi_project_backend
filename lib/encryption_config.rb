module EncryptionConfig
  Error = Class.new(StandardError)

  MINIMUM_KEY_LENGTH = 32

  KEYS = {
    primary_key:         "AR_ENCRYPTION_PRIMARY_KEY",
    deterministic_key:   "AR_ENCRYPTION_DETERMINISTIC_KEY",
    key_derivation_salt: "AR_ENCRYPTION_KEY_DERIVATION_SALT"
  }.freeze

  DEVELOPMENT_DEFAULTS = {
    primary_key:         "dev_primary_key_32_chars_padding!",
    deterministic_key:   "dev_deterministic_key_32chars_pad",
    key_derivation_salt: "dev_key_derivation_salt_32chars!!"
  }.freeze

  class << self
    def fetch!(env:, source: ENV)
      production = env.to_s == "production" && !build_time?(source)

      KEYS.to_h do |name, var|
        value = source[var].presence

        if production
          validate_production_key!(name, var, value)
        else
          value ||= DEVELOPMENT_DEFAULTS.fetch(name)
        end

        [ name, value ]
      end
    end

    private

    def build_time?(source)
      source["SECRET_KEY_BASE_DUMMY"].present?
    end

    def validate_production_key!(name, var, value)
      raise Error, "[Active Record Encryption] #{var} não configurada em produção. " \
                   "Gere valores reais com `bin/rails db:encryption:init` e publique-os " \
                   "no ambiente (Kamal: env.secret) antes do deploy." if value.blank?

      raise Error, "[Active Record Encryption] #{var} está usando o valor de desenvolvimento " \
                   "versionado no repositório. Gere uma chave real com " \
                   "`bin/rails db:encryption:init`." if value == DEVELOPMENT_DEFAULTS.fetch(name)

      raise Error, "[Active Record Encryption] #{var} tem #{value.length} caracteres; " \
                   "o mínimo é #{MINIMUM_KEY_LENGTH} (AES-256-GCM)." if value.length < MINIMUM_KEY_LENGTH
    end
  end
end
