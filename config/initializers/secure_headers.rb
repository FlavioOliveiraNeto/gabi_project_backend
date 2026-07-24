SecureHeaders::Configuration.default do |config|
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "0"

  config.hsts = "max-age=63072000; includeSubDomains; preload"

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
