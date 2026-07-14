# Factories — Convenções do Projeto

## Estrutura

- Um arquivo por model: `spec/factories/<model_name>.rb`
- Nome da factory no singular, snake_case: `factory :patient`, `factory :session_appointment`
- Arquivo nomeado igual ao model: `patient.rb`, `session_appointment.rb`

## Convenções

### Nomenclatura

```ruby
# CORRETO
factory :patient do ...
factory :session_appointment do ...
factory :clinical_note do ...

# ERRADO
factory :patients do ...      # plural
factory :Patient do ...       # CamelCase
```

### Dados com Faker

Sempre use Faker para dados dinâmicos — evita colisões em testes paralelos:

```ruby
factory :patient do
  name  { Faker::Name.full_name }
  email { Faker::Internet.unique.email }
  phone { Faker::PhoneNumber.cell_phone }
end
```

### Traits

Use traits para variações do mesmo model, não factories separadas:

```ruby
factory :patient do
  # estado padrão: ativo
  active { true }

  trait :inactive do
    active { false }
  end

  trait :with_clinical_notes do
    after(:create) { |patient| create_list(:clinical_note, 3, patient: patient) }
  end
end
```

### Associations

Declare associações com `association` ou `create` explícito:

```ruby
factory :session_appointment do
  association :patient
  association :psychologist, factory: :user
  scheduled_at { 1.week.from_now }
end
```

### Avoid `create` desnecessário

Prefira `build` ou `build_stubbed` quando o teste não precisa persistir no banco:

```ruby
# Mais rápido — sem hit no banco
patient = build(:patient)
patient = build_stubbed(:patient)

# Apenas quando precisa de ID ou associações persistidas
patient = create(:patient)
```

## Models esperados

| Factory                  | Model                  |
|--------------------------|------------------------|
| `:user`                  | `User` (psicóloga)     |
| `:patient`               | `Patient`              |
| `:session_appointment`   | `SessionAppointment`   |
| `:clinical_note`         | `ClinicalNote`         |

## Sequências globais

Defina sequências compartilhadas em `spec/factories/sequences.rb` (a criar):

```ruby
FactoryBot.define do
  sequence(:email) { |n| "user#{n}@example.com" }
  sequence(:cpf)   { |n| "000.000.000-#{n.to_s.rjust(2, '0')}" }
end
```
