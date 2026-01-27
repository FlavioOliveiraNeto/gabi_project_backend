FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "Password@123" }
    password_confirmation { 'Password@123' }
    confirmed_at { Time.current }
    role { :client }

    trait :admin do
      role { :admin }
    end
  end
end
