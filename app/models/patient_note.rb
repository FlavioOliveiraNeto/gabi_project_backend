class PatientNote < ApplicationRecord
  belongs_to :user

  validates :content, presence: true, length: { maximum: 10_000 }
  encrypts :content
end
