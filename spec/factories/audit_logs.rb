FactoryBot.define do
  factory :audit_log do
    association :user
    action      { "create" }
    entity_type { "Session" }
    sequence(:entity_id) { |n| n }
    metadata    { {} }
  end
end
