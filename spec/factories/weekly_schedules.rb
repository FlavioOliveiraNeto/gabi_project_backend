FactoryBot.define do
  factory :weekly_schedule do
    user { nil }
    weekday { 1 }
    time { "MyString" }
    sessions_per_week { 1 }
  end
end
