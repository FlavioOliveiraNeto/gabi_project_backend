FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@exemplo.com" }
    name             { Faker::Name.name }
    password         { "Password@123" }
    password_confirmation { "Password@123" }
    role             { :client }

    trait :therapist do
      role { :therapist }
    end

    trait :client do
      role { :client }
    end

    trait :must_change_password do
      must_change_password { true }
    end

    trait :with_meet_link do
      google_meet_link { "https://meet.google.com/abc-defg-hij" }
    end
  end
end
