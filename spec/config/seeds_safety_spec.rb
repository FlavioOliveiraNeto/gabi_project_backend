RSpec.describe "db/seeds.rb — segurança" do
  seeds = Pathname.new(File.expand_path("../../db/seeds.rb", __dir__))

  let(:content) { seeds.read }

  let(:active) do
    content.lines.map { |line| line.sub(/#.*/, "") }.join
  end

  it "aborta em produção sem opt-in explícito" do
    expect(content).to match(/Rails\.env\.production\?/),
      "db/seeds.rb apaga User/Session/ClinicalNote. Ele PRECISA de um guard de " \
      "produção — db:prepare roda no boot de todo container."
  end

  it "exige SEED_ALLOW_PRODUCTION para rodar em produção" do
    expect(content).to include("SEED_ALLOW_PRODUCTION")
  end

  it "usa return em vez de abort, para não derrubar o db:prepare no boot" do
    guard = content[/if Rails\.env\.production\?.*?\nend/m].to_s

    expect(guard).to include("return")
    expect(guard).not_to include("abort")
  end

  it "posiciona o guard de produção antes de qualquer delete_all" do
    guard_at  = active.index("SEED_ALLOW_PRODUCTION")
    delete_at = active.index("delete_all")

    expect(guard_at).not_to be_nil
    expect(delete_at).to be_nil.or be > guard_at
  end

  it "só apaga dados sob opt-in explícito (SEED_RESET)" do
    return if active.index("delete_all").nil?

    reset_at  = active.index("SEED_RESET")
    delete_at = active.index("delete_all")

    expect(reset_at).not_to be_nil,
      "db/seeds.rb chama delete_all sem estar sob SEED_RESET. Apagar dado precisa " \
      "ser opt-in explícito."
    expect(reset_at).to be < delete_at
  end

  it "cria registros de forma idempotente" do
    expect(active).to include("find_or_create_by!")
    expect(active).not_to match(/^\s*User\.create!/)
  end

  it "não usa aleatoriedade, que quebraria a idempotência" do
    expect(active).not_to match(/\brand\b|\.sample\b/)
  end

  it "não versiona senha em texto claro" do
    literals = content.scan(/password(?:_confirmation)?:\s*"([^"]+)"/).flatten

    expect(literals).to be_empty,
      "Senha literal em db/seeds.rb: #{literals.inspect}. Use SEED_PASSWORD."
  end

  it "não versiona o e-mail real da terapeuta" do
    expect(content).not_to match(/@gmail\.com|@hotmail\.com|@outlook\.com/)
  end

  it "respeita o comprimento mínimo de senha do Devise" do
    default = content[/SEED_PASSWORD\s*=\s*ENV\.fetch\("SEED_PASSWORD",\s*"([^"]+)"\)/, 1]

    expect(default).not_to be_nil
    expect(default.length).to be >= 12
  end
end
