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

  def self.auto_complete_past_sessions!
    where(status: :scheduled, session_type: :regular)
      .where("scheduled_at <= ?", 1.hour.ago)
      .update_all(status: Session.statuses[:completed])
  end
end