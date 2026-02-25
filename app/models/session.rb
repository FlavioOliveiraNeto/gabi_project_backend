class Session < ApplicationRecord
  belongs_to :user

  enum :status, {
    scheduled: 0,
    completed: 1,
    absent: 2,
    cancelled: 3
  }

  enum :session_type, {
    regular: 0,
    extra: 1
  }

  validates :scheduled_at, presence: true
  validate :no_schedule_conflict

  def self.auto_complete_past_sessions!
    where(status: :scheduled)
      .where("scheduled_at <= ?", 1.hour.ago)
      .update_all(status: Session.statuses[:completed])
  end

  private

  def no_schedule_conflict
    return unless scheduled_at.present?

    therapist = user&.therapist
    return unless therapist

    conflict = Session
      .joins(:user)
      .where(users: { therapist_id: therapist.id })
      .where(status: :scheduled)
      .where.not(id: id)
      .where(
        "scheduled_at > ? AND scheduled_at < ?",
        scheduled_at - 1.hour,
        scheduled_at + 1.hour
      )
      .exists?

    errors.add(:scheduled_at, "conflita com outra sessão agendada (intervalo mínimo de 1 hora)") if conflict
  end
end