FactoryBot.define do
  factory :jwt_denylist do
    jti { "MyString" }
    exp { "2026-02-05 16:23:46" }
  end
end
