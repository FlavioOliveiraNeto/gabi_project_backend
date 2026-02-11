FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "Password@123" }
    password_confirmation { 'Password@123' }
    confirmed_at { Time.current }
    role { :client }
    
    sessions_count { rand(0..10) }
    google_meet_link { "https://meet.google.com/#{Faker::Alphanumeric.alpha(number: 10)}" }

    trait :admin do
      role { :admin }
    end
  end
end