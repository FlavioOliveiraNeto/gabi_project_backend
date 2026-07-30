RSpec.describe "config/environments/production.rb — diretivas de segurança" do
  production_config = Pathname.new(File.expand_path("../../config/environments/production.rb", __dir__))

  let(:active_lines) do
    production_config.read.lines
                     .map { |line| line.sub(/#.*/, "").strip }
                     .reject(&:empty?)
  end

  def expect_directive(lines, pattern, description)
    expect(lines).to include(a_string_matching(pattern)),
      "Esperava #{description} ativo em config/environments/production.rb. " \
      "Verifique se a linha não foi comentada."
  end

  it "força SSL em todas as requisições" do
    expect_directive(active_lines, /\Aconfig\.force_ssl\s*=\s*true\z/, "config.force_ssl = true")
  end

  it "assume TLS terminado no proxy reverso" do
    expect_directive(active_lines, /\Aconfig\.assume_ssl\s*=\s*true\z/, "config.assume_ssl = true")
  end

  it "isenta o health check do redirect HTTPS" do
    expect_directive(active_lines, /\Aconfig\.ssl_options\s*=/, "config.ssl_options com exclusão de /up")
  end

  it "restringe os hosts aceitos" do
    expect_directive(active_lines, /\Aconfig\.hosts\s*=/, "config.hosts")
  end

  it "isenta o health check da verificação de Host" do
    expect_directive(active_lines, /\Aconfig\.host_authorization\s*=/, "config.host_authorization")
  end

  it "deriva config.hosts de APP_HOST em vez de um domínio fixo" do
    expect(active_lines).to include(a_string_matching(/APP_HOST/))
  end

  it "não deixa example.com como host de mailer" do
    expect(active_lines).not_to include(a_string_matching(/example\.com/))
  end

  it "não expõe relatórios de erro completos" do
    expect_directive(active_lines, /\Aconfig\.consider_all_requests_local\s*=\s*false\z/,
                     "config.consider_all_requests_local = false")
  end

  it "não roda em log_level debug por padrão" do
    expect(active_lines).not_to include(a_string_matching(/config\.log_level\s*=\s*["']debug["']/))
  end
end
