# frozen_string_literal: true

FactoryBot.define do
  factory :clinical_note do
    association :user, factory: %i[user client]
    association :session, factory: %i[session past]
    content { Faker::Lorem.paragraph(sentence_count: 5) }
  end
end
