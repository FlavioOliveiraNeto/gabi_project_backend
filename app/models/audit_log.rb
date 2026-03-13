# frozen_string_literal: true

class AuditLog < ApplicationRecord
  # ── Imutabilidade ─────────────────────────────────────────────────────────
  # Logs de auditoria não podem ser alterados ou removidos após criação.

  def readonly?
    persisted?
  end

  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  # ── Associações ─────────────────────────────────────────────────────────────

  belongs_to :user

  # ── Validações ──────────────────────────────────────────────────────────────

  validates :action,      presence: true
  validates :entity_type, presence: true
  validates :entity_id,   presence: true

  # ── Escopos ─────────────────────────────────────────────────────────────────

  scope :for_entity, ->(type, id) { where(entity_type: type, entity_id: id) }
  scope :for_user,   ->(user) { where(user: user) }
  scope :recent,     -> { order(created_at: :desc) }
end
