FactoryBot.define do
  factory :jwt_denylist do
    jti { SecureRandom.uuid }
    exp { 30.minutes.from_now }

    trait :expired do
      exp { 1.hour.ago }
    end
  end
end
