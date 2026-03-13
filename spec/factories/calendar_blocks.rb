# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_block do
    start_time { 1.day.from_now.beginning_of_hour }
    end_time   { 1.day.from_now.beginning_of_hour + 2.hours }
    reason     { "Férias da terapeuta" }

    trait :upcoming do
      start_time { 1.week.from_now.beginning_of_hour }
      end_time   { 1.week.from_now.beginning_of_hour + 3.hours }
    end

    trait :past do
      start_time { 1.week.ago.beginning_of_hour }
      end_time   { 1.week.ago.beginning_of_hour + 2.hours }
    end

    trait :long do
      start_time { 1.day.from_now.beginning_of_hour }
      end_time   { 1.day.from_now.beginning_of_hour + 8.hours }
    end
  end
end
