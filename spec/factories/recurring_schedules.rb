# frozen_string_literal: true

FactoryBot.define do
  factory :recurring_schedule do
    association :user, factory: %i[user client]
    weekday          { 1 }           # segunda-feira
    start_time       { "14:00:00" }
    duration_minutes { 50 }
    meet_link        { nil }
    active           { true }

    trait :inactive do
      active { false }
    end

    trait :with_meet_link do
      meet_link { "https://meet.google.com/abc-defg-hij" }
    end

    trait :monday do
      weekday { 1 }
    end

    trait :friday do
      weekday { 5 }
    end
  end
end
