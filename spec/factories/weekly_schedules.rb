FactoryBot.define do
  factory :weekly_schedule do
    association :user
    weekday           { :monday }
    time              { "10:00" }
    sessions_per_week { 1 }
    effective_from    { Date.current }
    effective_until   { nil }

    trait :monday    do weekday { :monday }    end
    trait :tuesday   do weekday { :tuesday }   end
    trait :wednesday do weekday { :wednesday } end
    trait :thursday  do weekday { :thursday }  end
    trait :friday    do weekday { :friday }    end
    trait :saturday  do weekday { :saturday }  end

    # Schedule encerrado no passado (histórico)
    trait :expired do
      effective_from  { 3.months.ago.to_date }
      effective_until { 1.month.ago.to_date }
    end

    # Schedule que ainda não entrou em vigor
    trait :future do
      effective_from { 1.month.from_now.to_date }
    end
  end
end
