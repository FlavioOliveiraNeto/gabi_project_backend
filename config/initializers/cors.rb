# Origens permitidas lidas exclusivamente de variáveis de ambiente.
# Em desenvolvimento, o padrão é localhost:5173 (Vite dev server).
# Em produção, configure FRONTEND_URL com a URL real (ex: https://meusite.com).
# Para múltiplas origens, separe por vírgula: FRONTEND_URL=https://a.com,https://b.com
allowed_origins = ENV
  .fetch("FRONTEND_URL", "http://localhost:5173")
  .split(",")
  .map(&:strip)
  .freeze

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization"]
  end
end
