FactoryBot.define do
  factory :session do
    association :user
    scheduled_at { 1.week.from_now }
    status       { :scheduled }
    session_type { :regular }

    trait :scheduled  do status { :scheduled }  end
    trait :completed  do status { :completed }  end
    trait :absent     do status { :absent }     end
    trait :cancelled  do status { :cancelled }  end

    trait :regular do session_type { :regular } end
    trait :extra   do session_type { :extra }   end

    # Sessão no passado (mais de 1h atrás — elegível para auto-complete)
    trait :past do
      scheduled_at { 2.hours.ago }
      status       { :scheduled }
    end
  end
end
