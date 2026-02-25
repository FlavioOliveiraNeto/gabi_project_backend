class User < ApplicationRecord
  enum :role, { therapist: 0, client: 1 }

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
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

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  validates :google_meet_link,
            format: { with: /\Ahttps?:\/\//i, message: "deve começar com http:// ou https://" },
            allow_blank: true

  # Força troca de senha no primeiro login
  def must_change_password?
    self.must_change_password
  end

  # Após trocar a senha, remove a obrigatoriedade
  def clear_must_change_password!
    update_column(:must_change_password, false)
  end
end
