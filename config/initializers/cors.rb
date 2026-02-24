allowed_origins = [
  ENV.fetch("FRONTEND_URL", "http://localhost:5173"),
  "http://localhost:5173",
  "http://localhost:8080"
].uniq.freeze

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"]
  end
end
