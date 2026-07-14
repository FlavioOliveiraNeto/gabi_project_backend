allowed_origins = ENV
  .fetch("FRONTEND_URL", "http://localhost:5173")
  .split(",")
  .map(&:strip)
  .freeze

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers:     :any,
      methods:     [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true,
      expose:      ["X-CSRF-Token"]
  end
end
