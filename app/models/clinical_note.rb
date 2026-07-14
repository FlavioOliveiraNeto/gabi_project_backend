# frozen_string_literal: true

class ClinicalNote < ApplicationRecord
  # ── Associações ─────────────────────────────────────────────────────────────

  belongs_to :user
  belongs_to :session

  # Mantido para dados legados (pode ser nil em registros novos)
  belongs_to :therapist, class_name: "User", optional: true

  # ── Criptografia ─────────────────────────────────────────────────────────────

  encrypts :content

  # ── Validações ──────────────────────────────────────────────────────────────

  validates :user,    presence: true
  validates :session, presence: true
  validates :content, presence: true, length: { maximum: 10_000 }

  validates :session_id, uniqueness: { message: "já possui uma anotação clínica" }

  validate :user_matches_session_user

  private

  def user_matches_session_user
    return unless session.present? && user.present?

    if session.user_id != user_id
      errors.add(:user_id, "deve corresponder ao usuário da sessão")
    end
  end
end
