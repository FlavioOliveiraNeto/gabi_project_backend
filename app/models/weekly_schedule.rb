class WeeklySchedule < ApplicationRecord
  belongs_to :user

  enum :weekday, {
    sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
    thursday: 4, friday: 5, saturday: 6
  }

  validates :weekday,        presence: true
  validates :effective_from, presence: true
  validates :time, presence: true, format: {
    with: /\A([01]\d|2[0-3]):[0-5]\d\z/,
    message: "deve estar no formato HH:MM (ex: 14:30)"
  }

  validate :effective_until_after_effective_from

  scope :active, -> {
    where("effective_from <= ?", Date.current)
      .where("effective_until IS NULL OR effective_until >= ?", Date.current)
  }

  scope :effective_on, ->(date) {
    where("effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until >= ?", date)
  }

  scope :overlapping, ->(start_date, end_date) {
    where("effective_from <= ?", end_date)
      .where("COALESCE(effective_until, ?) >= ?", Date.current, start_date)
  }

  def active?
    effective_from <= Date.current &&
      (effective_until.nil? || effective_until >= Date.current)
  end

  def close!(until_date)
    update!(effective_until: until_date)
  end

  private

  def effective_until_after_effective_from
    return unless effective_from.present? && effective_until.present?

    if effective_until < effective_from
      errors.add(:effective_until, "deve ser posterior a effective_from")
    end
  end
end
