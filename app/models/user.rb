class User < ApplicationRecord
  include Auditable

  enum :role, { therapist: 0, client: 1 }

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  # Legado: terapeuta -> seus clientes (mantido para os controllers existentes)
  has_many :patients,
           class_name:  "User",
           foreign_key: "therapist_id",
           dependent:   :nullify

  belongs_to :therapist,
             class_name: "User",
             optional:   true

  # design novo
  has_many :sessions,            dependent: :destroy
  has_many :recurring_schedules, dependent: :destroy
  has_many :clinical_notes,      dependent: :destroy
  has_many :audit_logs,          dependent: :destroy

  has_many :calendar_blocks,
           foreign_key: "therapist_id",
           dependent:   :destroy

  # Legado (mantido enquanto controllers antigos usam esses models)
  has_many :patient_notes,   dependent: :destroy
  has_many :weekly_schedules, dependent: :destroy

  validates :name, presence: true
  validates :role, presence: true

  ALLOWED_MEET_HOSTS = %w[meet.google.com].freeze

  validate :google_meet_link_is_safe_https_url, if: -> { google_meet_link.present? }

  # ── Escopos ─────────────────────────────────────────────────────────────────

  scope :clients,  -> { where(role: :client) }
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # ── Callbacks ───────────────────────────────────────────────────────────────

  after_update :cancel_future_sessions_if_deactivated

  def must_change_password?
    must_change_password
  end

  def clear_must_change_password!
    update_column(:must_change_password, false)
  end

  private

  def google_meet_link_is_safe_https_url
    uri = URI.parse(google_meet_link)

    unless uri.is_a?(URI::HTTPS) && ALLOWED_MEET_HOSTS.include?(uri.host&.downcase)
      errors.add(:google_meet_link, "deve ser uma URL HTTPS de #{ALLOWED_MEET_HOSTS.join(', ')}")
    end
  rescue URI::InvalidURIError
    errors.add(:google_meet_link, "não é uma URL válida")
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
