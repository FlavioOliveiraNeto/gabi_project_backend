# frozen_string_literal: true

SecureHeaders::Configuration.default do |config|
  # Proteções básicas
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0"

  # HTTPS
  config.hsts = "max-age=63072000; includeSubDomains; preload"

  # CSP (Content Security Policy)
  config.csp = {
    default_src: %w['self'],
    script_src: %w['self'],
    style_src: %w['self' 'unsafe-inline'],
    img_src: %w['self' data:],
    font_src: %w['self'],
    connect_src: %w['self'],
    object_src: %w['none'],
    frame_ancestors: %w['none']
  }
end
