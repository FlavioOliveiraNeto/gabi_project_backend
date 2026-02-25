FactoryBot.define do
  factory :patient_note do
    association :user
    content { Faker::Lorem.paragraph }
  end
end
