FactoryBot.define do
  factory :clinical_note do
    content { Faker::Lorem.paragraph }
    date    { Time.current }
    association :user
    association :therapist, factory: :user, role: :therapist
  end
end
