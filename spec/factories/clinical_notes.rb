# frozen_string_literal: true

FactoryBot.define do
  factory :clinical_note do
    association :session, factory: %i[session past]
    user { session.user }
    content { Faker::Lorem.paragraph(sentence_count: 5) }
  end
end
