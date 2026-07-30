RSpec.describe "Configuração dos jobs em background" do
  backend_root = Pathname.new(File.expand_path("../..", __dir__))
  repo_root    = backend_root.parent

  def compose_backend_env(path)
    return nil unless path.exist?

    content = path.read
    content[/^\s{2}backend:.*?(?=^\s{2}\w|\z)/m].to_s
  end

  let(:prod_compose) { repo_root.join("docker-compose.prod.yml") }
  let(:dev_compose)  { repo_root.join("docker-compose.yml") }
  let(:puma_config)  { backend_root.join("config/puma.rb") }

  it "o plugin do SolidQueue continua condicionado a SOLID_QUEUE_IN_PUMA" do
    expect(puma_config.read).to match(/plugin :solid_queue if ENV\["SOLID_QUEUE_IN_PUMA"\]/)
  end

  it "produção declara um serviço worker dedicado" do
    expect(prod_compose.read).to match(/^\s{2}worker:$/),
      "docker-compose.prod.yml não declara o serviço `worker`. Sem ele (e sem " \
      "SOLID_QUEUE_IN_PUMA no backend) NENHUM job roda em produção, " \
      "silenciosamente. Verifique com `bin/rails jobs:health`."
  end

  it "o worker de produção executa bin/jobs" do
    worker = prod_compose.read[/^\s{2}worker:.*?(?=^\s{2}\w|\z)/m].to_s

    expect(worker).to match(%r{bin/jobs})
  end

  it "o worker espera o backend ficar saudável (migrations prontas)" do
    worker = prod_compose.read[/^\s{2}worker:.*?(?=^\s{2}\w|\z)/m].to_s

    expect(worker).to include("backend:")
    expect(worker).to include("service_healthy")
  end

  it "o backend de produção tem healthcheck, que é o gate do worker" do
    backend = compose_backend_env(prod_compose)

    expect(backend).to include("healthcheck")
  end

  it "o backend de produção NÃO roda jobs dentro do Puma" do
    backend = compose_backend_env(prod_compose)
    active  = backend.to_s.lines.reject { |l| l.strip.start_with?("#") }.join

    expect(active).not_to match(/SOLID_QUEUE_IN_PUMA:\s*["']?true/)
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
