# Filtra warnings de gems externas mantendo os do código da aplicação.
# Usa Warning.prepend (Ruby 2.7+) — não silencia o stderr inteiro.
module GemWarningFilter
  def warn(message, category: nil, **kwargs)
    return if Gem.path.any? { |gem_path| message.to_s.include?(gem_path) }

    if category
      super(message, category: category, **kwargs)
    else
      super(message)
    end
  end
end

Warning.prepend(GemWarningFilter)

RSpec.configure do |config|
  # Usa apenas a sintaxe :expect (sem monkey-patching de should/expect no objeto)
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Doubles verificados — garante que métodos stubados existem no objeto real
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Metadados de shared context herdados pelo hash do grupo/exemplo host
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Executa apenas exemplos marcados com :focus quando presentes
  config.filter_run_when_matching :focus

  # Ordem aleatória para detectar dependências entre specs
  config.order = :random
  Kernel.srand config.seed

  # Habilita warnings do Ruby (gems externas já filtradas pelo GemWarningFilter acima)
  config.warnings = true

  # Persiste status dos exemplos entre execuções (suporta --only-failures)
  config.example_status_persistence_file_path = ".rspec_status"
end
