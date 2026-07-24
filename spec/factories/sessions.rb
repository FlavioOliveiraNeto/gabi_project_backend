FactoryBot.define do
  factory :session do
    association :user, factory: %i[user client]
    recurring_schedule { nil }
    scheduled_at { nil }
    start_time   { scheduled_at || 1.week.from_now.beginning_of_hour }
    end_time     { start_time + 50.minutes }
    status       { :scheduled }
    session_type { :recurring }
    meet_link    { nil }

    trait :completed do
      status     { :completed }
      start_time { 1.week.ago.beginning_of_hour }
      end_time   { 1.week.ago.beginning_of_hour + 50.minutes }
    end

    trait :absent do
      status     { :absent }
      start_time { 2.weeks.ago.beginning_of_hour }
      end_time   { 2.weeks.ago.beginning_of_hour + 50.minutes }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :extra do
      session_type { :extra }
    end

    trait :past do
      status     { :completed }
      start_time { 1.week.ago.beginning_of_hour }
      end_time   { 1.week.ago.beginning_of_hour + 50.minutes }
    end

    trait :future do
      start_time { 1.week.from_now.beginning_of_hour }
      end_time   { 1.week.from_now.beginning_of_hour + 50.minutes }
    end

    trait :with_meet_link do
      meet_link { "https://meet.google.com/xyz-abcd-efg" }
    end
  end
end
