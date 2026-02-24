class ClinicalNote < ApplicationRecord
  belongs_to :user      # paciente (user_id = patient_id)
  belongs_to :therapist, class_name: "User"

  validates :content, presence: true, length: { maximum: 10_000 }
  encrypts :content
end
