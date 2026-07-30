class User < ApplicationRecord
  include Auditable
  include MeetLinkValidatable

  enum :role, { therapist: 0, client: 1 }

  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable,
         :lockable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtRevocation

  has_many :patients,
           class_name:  "User",
           foreign_key: "therapist_id",
           dependent:   :nullify

  belongs_to :therapist,
             class_name: "User",
             optional:   true

  has_many :sessions,            dependent: :destroy
  has_many :recurring_schedules, dependent: :destroy
  has_many :clinical_notes,      dependent: :destroy
  has_many :audit_logs,          dependent: :destroy

  has_many :calendar_blocks,
           foreign_key: "therapist_id",
           dependent:   :destroy

  has_many :patient_notes,   dependent: :destroy
  has_many :weekly_schedules, dependent: :destroy

  validates :name, presence: true
  validates :role, presence: true

  validates_meet_link :google_meet_link

  scope :clients,  -> { where(role: :client) }
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  after_update :cancel_future_sessions_if_deactivated

  after_update :revoke_all_jwts!, if: :credentials_invalidated?

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :account_inactive
  end

  def jwt_payload
    { JwtRevocation::VERSION_CLAIM => token_version }
  end

  def revoke_all_jwts!
    update_column(:token_version, token_version + 1)
  end

  def must_change_password?
    must_change_password
  end

  def clear_must_change_password!
    update_column(:must_change_password, false)
  end

  private

  def credentials_invalidated?
    saved_change_to_encrypted_password? || account_deactivated?
  end

  def account_deactivated?
    saved_change_to_active? && !active?
  end

  def cancel_future_sessions_if_deactivated
    return unless saved_change_to_active? && !active?

    sessions
      .where(status: Session.statuses[:scheduled])
      .where("start_time > ?", Time.current)
      .update_all(status: Session.statuses[:cancelled], updated_at: Time.current)

    log_audit("deactivate")
  end
end
