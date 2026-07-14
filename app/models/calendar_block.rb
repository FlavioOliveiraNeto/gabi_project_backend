# frozen_string_literal: true

class CalendarBlock < ApplicationRecord
  include Auditable

  # ── Validações ──────────────────────────────────────────────────────────────

  validates :start_time, presence: true
  validates :end_time,   presence: true
  validates :reason,     presence: true

  validate :end_time_after_start_time
  validate :no_overlapping_blocks

  # ── Escopos ─────────────────────────────────────────────────────────────────

  scope :upcoming,  -> { where("start_time > ?", Time.current) }
  scope :covering,  ->(time) { where("start_time <= ? AND end_time > ?", time, time) }

  # ── Callbacks de auditoria ──────────────────────────────────────────────────

  after_create { log_audit("create") }

  # ── Métodos de instância ────────────────────────────────────────────────────

  def duration_in_hours
    return 0.0 unless start_time && end_time

    (end_time - start_time) / 3600.0
  end

  private

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    errors.add(:end_time, "deve ser posterior a start_time") if end_time <= start_time
  end

  def no_overlapping_blocks
    return unless start_time.present? && end_time.present?

    overlap = CalendarBlock
      .where.not(id: id)
      .where("start_time < ? AND end_time > ?", end_time, start_time)
      .exists?

    errors.add(:start_time, "sobrepõe um bloqueio de agenda existente") if overlap
  end
end
