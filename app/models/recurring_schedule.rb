class RecurringSchedule < ApplicationRecord
  include Auditable

  WEEKDAY_NAMES = %w[domingo segunda-feira terça-feira quarta-feira quinta-feira sexta-feira sábado].freeze

  belongs_to :user
  has_many   :sessions, dependent: :nullify

  validates :user,             presence: true
  validates :weekday,          presence: true, inclusion: { in: 0..6 }
  validates :start_time,       presence: true
  validates :duration_minutes, presence: true,
                               numericality: { greater_than: 0, less_than_or_equal_to: 60 }

  validates :meet_link,
            format: { with: /\Ahttps?:\/\//i, message: "deve ser uma URL válida (http/https)" },
            allow_blank: true

  scope :active, -> { where(active: true) }

  before_update :purge_future_sessions_if_schedule_changed
  after_update  { log_audit("update") }

  def end_time
    return nil unless start_time

    start_time + duration_minutes.minutes
  end

  def weekday_name
    WEEKDAY_NAMES[weekday]
  end

  private

  def purge_future_sessions_if_schedule_changed
    schedule_time_changed = will_save_change_to_weekday? || will_save_change_to_start_time?
    deactivating          = will_save_change_to_active? && !active

    return unless schedule_time_changed || deactivating

    sessions
      .where("start_time > ?", Time.current)
      .delete_all
  end
end
