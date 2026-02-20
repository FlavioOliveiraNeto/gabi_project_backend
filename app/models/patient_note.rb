class PatientNote < ApplicationRecord
  belongs_to :user

  validates :content, presence: true
  encrypts :content
end
