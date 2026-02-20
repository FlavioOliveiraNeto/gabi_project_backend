class User < ApplicationRecord
  enum :role, { therapist: 0, client: 1 }

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  # Terapeuta
  has_many :patients,
           class_name: "User",
           foreign_key: "therapist_id",
           dependent: :destroy

  # Paciente
  belongs_to :therapist,
             class_name: "User",
             optional: true

  has_many :sessions, dependent: :destroy
  has_many :clinical_notes, dependent: :destroy
  has_many :patient_notes, dependent: :destroy
  has_many :weekly_schedules, dependent: :destroy
end
