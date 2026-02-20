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
    extra: 1,
    emergency: 2
  }
end