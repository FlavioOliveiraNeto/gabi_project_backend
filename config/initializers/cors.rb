allowed_origins = ENV
  .fetch("FRONTEND_URL", "http://localhost:5173")
  .split(",")
  .map(&:strip)
  .reject(&:empty?)
  .freeze

if allowed_origins.empty?
  raise "[CORS] FRONTEND_URL não define nenhuma origem válida."
end

if allowed_origins.include?("*")
  raise "[CORS] FRONTEND_URL não pode conter '*': com credentials: true isso " \
        "expõe o csrf_token a qualquer site e anula a proteção CSRF."
end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers:     :any,
      methods:     [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true,
      expose:      [ "X-CSRF-Token" ]
  end
end
