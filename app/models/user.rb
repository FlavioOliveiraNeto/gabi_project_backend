# frozen_string_literal: true

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

  # ── Associações ─────────────────────────────────────────────────────────────

  # Legado: terapeuta → seus clientes (mantido para os controllers existentes)
  has_many :patients,
           class_name:  "User",
           foreign_key: "therapist_id",
           dependent:   :nullify

  belongs_to :therapist,
             class_name: "User",
             optional:   true

  # Novo design
  has_many :sessions,            dependent: :destroy
  has_many :recurring_schedules, dependent: :destroy
  has_many :clinical_notes,      dependent: :destroy
  has_many :audit_logs,          dependent: :destroy

  # Legado (mantido enquanto controllers antigos usam esses models)
  has_many :patient_notes,   dependent: :destroy
  has_many :weekly_schedules, dependent: :destroy

  # ── Validações ──────────────────────────────────────────────────────────────

  # Devise::Validatable já valida email (presença, unicidade, formato) e password.
  # Adicionamos apenas validações extras.
  validates :name, presence: true
  validates :role, presence: true

  validates :google_meet_link,
            format: { with: /\Ahttps?:\/\//i, message: "deve começar com http:// ou https://" },
            allow_blank: true

  # ── Escopos ─────────────────────────────────────────────────────────────────

  scope :clients,  -> { where(role: :client) }
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # ── Callbacks ───────────────────────────────────────────────────────────────

  after_update :cancel_future_sessions_if_deactivated

  # ── Compatibilidade legada ───────────────────────────────────────────────────

  # Controllers antigos usam must_change_password?; delegamos para o novo campo.
  def must_change_password?
    force_password_change?
  end

  def clear_must_change_password!
    update_column(:force_password_change, false)
  end

  private

  def cancel_future_sessions_if_deactivated
    return unless saved_change_to_active? && !active?

    sessions
      .where(status: Session.statuses[:scheduled])
      .where("start_time > ?", Time.current)
      .update_all(status: Session.statuses[:cancelled], updated_at: Time.current)

    log_audit("deactivate")
  end
end
