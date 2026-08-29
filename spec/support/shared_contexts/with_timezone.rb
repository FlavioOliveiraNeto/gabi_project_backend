# Shared context de timezone para specs que precisam de controle explícito.
#
# O rails_helper já aplica Time.use_zone("America/Sao_Paulo") globalmente
# via config.around(:each). Use este shared context apenas quando quiser
# testar comportamento em um fuso diferente ou documentar a dependência
# de timezone de forma explícita no spec.
#
# Uso padrão (São Paulo já é o default global):
#   include_context "com fuso de São Paulo"
#
# Uso para testar em outro fuso:
#   include_context "com fuso horário", "UTC"
#   include_context "com fuso horário", "America/New_York"

RSpec.shared_context "com fuso de São Paulo" do
  around { |example| Time.use_zone("America/Sao_Paulo") { example.run } }
end

RSpec.shared_context "com fuso horário" do |zone_name|
  around { |example| Time.use_zone(zone_name) { example.run } }
end
