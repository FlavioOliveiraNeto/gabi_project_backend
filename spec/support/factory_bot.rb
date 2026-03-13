RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # factory_bot_rails carrega os factories automaticamente via Railtie quando o
  # Rails inicializa. Chamar find_definitions aqui causaria DuplicateDefinitionError
  # agora que existem arquivos em spec/factories/. O bloco abaixo garante que os
  # factories estejam disponíveis mesmo quando factory_bot_rails não estiver em uso.
  config.before(:suite) do
    FactoryBot.reload
  end
end
