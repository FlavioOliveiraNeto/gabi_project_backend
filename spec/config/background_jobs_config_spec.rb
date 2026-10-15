RSpec.describe "Configuração dos jobs em background" do
  backend_root = Pathname.new(File.expand_path("../..", __dir__))
  repo_root    = backend_root.parent

  def compose(path)
    skip "#{path.basename} não montado neste contexto" unless path.exist?

    path.read
  end

  def compose_backend_env(path)
    content = compose(path)
    content[/^\s{2}backend:.*?(?=^\s{2}\w|\z)/m].to_s
  end

  let(:prod_compose) { repo_root.join("docker-compose.prod.yml") }
  let(:dev_compose)  { repo_root.join("docker-compose.yml") }
  let(:puma_config)  { backend_root.join("config/puma.rb") }

  it "o plugin do SolidQueue continua condicionado a SOLID_QUEUE_IN_PUMA" do
    expect(puma_config.read).to match(/plugin :solid_queue if ENV\["SOLID_QUEUE_IN_PUMA"\]/)
  end

  it "o backend de produção tem healthcheck (sinal de migrations prontas)" do
    backend = compose_backend_env(prod_compose)

    expect(backend).to include("healthcheck")
  end

  # Decisão de 2026-09: sem serviço `worker` — a VM de 956Mi entrava em swap
  # com um segundo processo Rails. Os jobs rodam dentro do Puma; se esta
  # variável sumir, NENHUM job roda em produção, silenciosamente.
  it "o backend de produção roda os jobs dentro do Puma" do
    backend = compose_backend_env(prod_compose)
    active  = backend.to_s.lines.reject { |l| l.strip.start_with?("#") }.join

    expect(active).to match(/SOLID_QUEUE_IN_PUMA:\s*["']?true/),
      "docker-compose.prod.yml não liga SOLID_QUEUE_IN_PUMA no backend e não há " \
      "serviço worker: nenhum job rodaria. Verifique com `bin/rails jobs:health`."
  end

  it "o Dockerfile torna bin/jobs executável e com LF" do
    dockerfile = backend_root.join("Dockerfile").read
    chmod_line = dockerfile[/^RUN sed -i.*?chmod \+x[^\n]*/m].to_s

    expect(chmod_line).to include("bin/jobs")
  end

  it "desenvolvimento define SOLID_QUEUE_IN_PUMA para o backend" do
    backend = compose_backend_env(dev_compose)

    expect(backend).to include("SOLID_QUEUE_IN_PUMA")
  end

  it "declara as três tarefas recorrentes em produção" do
    recurring = backend_root.join("config/recurring.yml").read

    expect(recurring).to include("AutoCompleteSessionsJob")
    expect(recurring).to include("WeeklySessionGenerationJob")
    expect(recurring).to include("CleanupJwtDenylistJob")
  end

  it "produção herda as tarefas recorrentes do bloco default" do
    recurring = backend_root.join("config/recurring.yml").read

    expect(recurring).to match(/^production:\s*\n\s*<<: \*default/)
  end
end
