class Session < ApplicationRecord
  include Auditable

  InvalidTransition = Class.new(StandardError)

  ALLOWED_DIRECT_TRANSITIONS = {
    "scheduled" => %w[cancelled],
    "completed" => %w[absent],
    "absent"    => [],
    "cancelled" => []
  }.freeze

  enum :status, {
    scheduled: 0,
    completed: 1,
    absent:    2,
    cancelled: 3
  }

  enum :session_type, {
    recurring: 0,
    extra:     1
  }

  belongs_to :user
  belongs_to :recurring_schedule, optional: true
  has_one    :clinical_note

  validates :user,         presence: true
  validates :start_time,   presence: true
  validates :end_time,     presence: true
  validates :status,       presence: true
  validates :session_type, presence: true

  validate :end_time_after_start_time
  validate :duration_within_limit
  validate :no_session_conflict
  validate :no_calendar_block_conflict
  validate :status_transition_valid

  scope :upcoming,  -> { scheduled.where("start_time > ?", Time.current) }
  scope :past,      -> { where("start_time < ?", Time.current) }
  scope :for_user,  ->(user) { where(user: user) }
  scope :in_range,  ->(from, to) { where(start_time: from..to) }

  after_create { log_audit("create") }

  def cancel!
    raise InvalidTransition, "Apenas sessões agendadas podem ser canceladas (status atual: #{status})" unless scheduled?

    update!(status: :cancelled)
    log_audit("cancel")
  end

  def mark_as_absent!
    raise InvalidTransition, "Apenas sessões concluídas podem ser marcadas como falta (status atual: #{status})" unless completed?

    update!(status: :absent)
    log_audit("mark_as_absent")
  end

  def auto_complete!
    raise InvalidTransition, "Apenas sessões agendadas podem ser auto-completadas (status atual: #{status})" unless scheduled?

    @bypass_status_validation = true
    update!(status: :completed)
  ensure
    @bypass_status_validation = false
  end

  def duration_in_minutes
    return 0 unless start_time && end_time

    ((end_time - start_time) / 60).round
  end

  def recurring?
    session_type == "recurring"
  end

  def extra?
    session_type == "extra"
  end

  def cancellable?
    scheduled?
  end

  def can_mark_as_absent?
    completed?
  end

  def self.auto_complete_past_sessions!
    where(status: :scheduled)
      .where("start_time <= ?", 1.hour.ago)
      .find_each(&:auto_complete!)
  end

  private

  def end_time_after_start_time
    return unless start_time.present? && end_time.present?

    errors.add(:end_time, "deve ser posterior a start_time") if end_time <= start_time
  end

  def duration_within_limit
    return unless start_time.present? && end_time.present?

    if (end_time - start_time) > 60.minutes
      errors.add(:end_time, "a sessão não pode exceder 60 minutos")
    end
  end

  def no_session_conflict
    return unless start_time.present? && end_time.present?
    return unless scheduled?
    return unless user.present?

    conflict = Session
      .where.not(id: id)
      .where(status: :scheduled)
      .joins(:user)
      .where(users: { therapist_id: user.therapist_id })
      .where("start_time < ? AND end_time > ?", end_time, start_time)
      .exists?

    errors.add(:start_time, "conflita com outra sessão já agendada") if conflict
  end

  def no_calendar_block_conflict
    return unless start_time.present? && end_time.present?
    return unless user&.therapist_id.present?

    conflict = CalendarBlock
      .where(therapist_id: user.therapist_id)
      .where("start_time < ? AND end_time > ?", end_time, start_time)
      .exists?

    errors.add(:start_time, "conflita com um bloqueio de agenda existente") if conflict
  end

  def status_transition_valid
    return if @bypass_status_validation
    return if new_record?
    return unless status_changed?

    from    = status_was.to_s
    to      = status.to_s
    allowed = ALLOWED_DIRECT_TRANSITIONS[from] || []

    unless allowed.include?(to)
      errors.add(:status, "transição de '#{from}' para '#{to}' não é permitida")
    end
  end
end
