RSpec.describe ".env.example completeness" do
  root = Pathname.new(File.expand_path("..", __dir__))

  IGNORED_ENV_VARS = %w[
    BUNDLE_GEMFILE CI PIDFILE WEB_CONCURRENCY RAILS_MAX_THREADS
    RAILS_ENV RAILS_LOG_TO_STDOUT RAILS_LOG_LEVEL RAILS_MASTER_KEY
    SECRET_KEY_BASE PORT JOB_CONCURRENCY
    SOLID_QUEUE_IN_PUMA GABI_PROJECT_BACKEND_DATABASE_PASSWORD
    SEED_ALLOW_PRODUCTION SEED_PASSWORD SEED_THERAPIST_EMAIL
    SECRET_KEY_BASE_DUMMY
  ].freeze

  let(:env_example) { File.read(root.join(".env.example")) }

  let(:documented_keys) do
    env_example.scan(/^#?\s*([A-Z][A-Z0-9_]+)=/).flatten.uniq
  end

  let(:referenced_keys) do
    files = Dir[root.join("app/**/*.rb"), root.join("config/**/*.rb"),
                root.join("config/**/*.yml"), root.join("lib/**/*.rb")]
    files.flat_map { |f| File.read(f).scan(/ENV(?:\.fetch)?\[?\(?["']([A-Z][A-Z0-9_]+)["']/).flatten }
         .uniq
  end

  it "documenta toda variável de ENV que a aplicação lê" do
    required = referenced_keys - IGNORED_ENV_VARS
    missing  = required - documented_keys

    expect(missing).to be_empty,
      "ENV vars read by the app but missing from .env.example: #{missing.join(', ')}. " \
      "Add them to .env.example or, if platform-provided, to IGNORED_ENV_VARS."
  end
end
