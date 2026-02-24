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

  def self.auto_complete_past_sessions!
    where(status: :scheduled)
      .where("scheduled_at < ?", Time.current)
      .update_all(status: Session.statuses[:completed])
  end
end