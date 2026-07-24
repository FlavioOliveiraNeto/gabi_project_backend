if ENV["SMTP_ADDRESS"].present?
  Rails.application.config.action_mailer.delivery_method = :smtp
  Rails.application.config.action_mailer.perform_deliveries = true
  Rails.application.config.action_mailer.raise_delivery_errors = true
  Rails.application.config.action_mailer.smtp_settings = {
    address:              ENV.fetch("SMTP_ADDRESS"),
    port:                 ENV.fetch("SMTP_PORT", "587").to_i,
    user_name:            ENV.fetch("SMTP_USER_NAME"),
    password:             ENV.fetch("SMTP_PASSWORD"),
    domain:               ENV.fetch("SMTP_DOMAIN", "gmail.com"),
    authentication:       :plain,
    enable_starttls_auto: true
  }
end
