FactoryBot.define do
  factory :clinical_note do
    content { Faker::Lorem.paragraph }
    date { Time.current }
    association :user
  end
end