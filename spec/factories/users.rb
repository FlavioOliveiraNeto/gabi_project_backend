# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "usuario#{n}@clinicagabi.com.br" }
    name     { Faker::Name.name }
    password { "Senha@123!" }
    role     { :therapist }
    phone    { Faker::PhoneNumber.phone_number }
    force_password_change { false }
    active   { true }

    trait :therapist do
      role { :therapist }
    end

    trait :client do
      role { :client }
    end

    trait :must_change_password do
      must_change_password { true }
    end

    trait :inactive do
      active { false }
    end
  end
end
