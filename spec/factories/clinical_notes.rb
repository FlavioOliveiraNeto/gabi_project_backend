# frozen_string_literal: true

FactoryBot.define do
  factory :clinical_note do
    user { create(:user, :client) }
    session { create(:session, :past, user: user) }
    content { Faker::Lorem.paragraph(sentence_count: 5) }
  end
end
