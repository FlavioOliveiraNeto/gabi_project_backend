class ScheduleChangeService
  Error = Class.new(StandardError)

  class ConflictError < Error
    attr_reader :conflicts

    def initialize(conflicts)
      @conflicts = conflicts
      super(ScheduleChangeService.conflict_message(conflicts))
    end
  end

  WEEKDAY_NAMES = {
    "sunday"    => "Domingo",
    "monday"    => "Segunda-feira",
    "tuesday"   => "Terça-feira",
    "wednesday" => "Quarta-feira",
    "thursday"  => "Quinta-feira",
    "friday"    => "Sexta-feira",
    "saturday"  => "Sábado"
  }.freeze

  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  def self.conflict_message(conflicts)
    listed = conflicts.map { |c| "#{WEEKDAY_NAMES.fetch(c[:weekday], c[:weekday])} às #{c[:time]}" }

    "Já existe uma sessão agendada em #{join_pt_br(listed)}. Escolha outro horário."
  end

  def self.join_pt_br(items)
    return items.first.to_s if items.size <= 1

    "#{items[0..-2].join(', ')} e #{items.last}"
  end

  def initialize(patient:, therapist:, effective_from:, schedule_type:, schedule_params: {})
    @patient         = patient
    @therapist       = therapist
    @effective_from  = effective_from.to_date
    @schedule_type   = schedule_type
    @schedule_params = schedule_params || {}
  end

  def call
    case @schedule_type
    when "regular"
      transition_to_regular!
    when "extra"
      transition_to_extra!
    end

    @patient
  end

  private

  def transition_to_regular!
    slots = normalized_slots
    validate_slots!(slots)

    ActiveRecord::Base.transaction do
      close_active_schedules!
      cancel_scheduled_sessions_from!(@effective_from)
      create_new_weekly_schedules!(slots)

      generator = SessionGeneratorService.new(@therapist)
      generator.generate_for_patient_from(@patient, from: @effective_from)

      raise ConflictError, generator.conflicts if generator.conflicts.any?
    end
  end

  def transition_to_extra!
    ActiveRecord::Base.transaction do
      close_active_schedules!
      cancel_scheduled_sessions_from!(@effective_from)
    end
  end

  def normalized_slots
    raw = @schedule_params[:schedule_slots] || @schedule_params["schedule_slots"]

    if raw.present?
      Array(raw).map do |slot|
        slot = slot.respond_to?(:to_unsafe_h) ? slot.to_unsafe_h : slot
        slot = slot.with_indifferent_access if slot.respond_to?(:with_indifferent_access)

        { weekday: slot[:weekday].to_s.strip, time: slot[:time].to_s.strip }
      end
    else
      session_time = (@schedule_params[:session_time] || @schedule_params["session_time"]).to_s.strip
      weekdays     = @schedule_params[:weekdays] || @schedule_params["weekdays"]

      Array(weekdays).compact.map { |weekday| { weekday: weekday.to_s.strip, time: session_time } }
    end
  end

  def validate_slots!(slots)
    raise Error, "Informe ao menos um dia da semana." if slots.empty?

    slots.each do |slot|
      unless WeeklySchedule.weekdays.key?(slot[:weekday])
        raise Error, "Dia da semana inválido: #{slot[:weekday].presence || '(vazio)'}."
      end

      unless slot[:time].match?(TIME_FORMAT)
        raise Error, "Horário inválido ou não informado para #{WEEKDAY_NAMES.fetch(slot[:weekday])}. Use o formato HH:MM."
      end
    end

    duplicated = slots.map { |slot| slot[:weekday] }.tally.select { |_, count| count > 1 }.keys
    return if duplicated.empty?

    raise Error, "Dia da semana repetido: #{self.class.join_pt_br(duplicated.map { |d| WEEKDAY_NAMES.fetch(d) })}."
  end

  def close_active_schedules!
    @patient.weekly_schedules
            .where("effective_from < ?", @effective_from)
            .where("effective_until IS NULL OR effective_until >= ?", @effective_from)
            .update_all(effective_until: @effective_from - 1.day)

    @patient.weekly_schedules
            .where("effective_from >= ?", @effective_from)
            .delete_all
  end

  def cancel_scheduled_sessions_from!(date)
    @patient.sessions
            .where(session_type: :recurring, status: :scheduled)
            .where("scheduled_at >= ?", date.beginning_of_day)
            .update_all(
              status:     Session.statuses[:cancelled],
              updated_at: Time.current
            )
  end

  def create_new_weekly_schedules!(slots)
    sessions_per_week = @schedule_params[:sessions_per_week].presence ||
                        @schedule_params["sessions_per_week"].presence ||
                        slots.size

    slots.each do |slot|
      @patient.weekly_schedules.create!(
        weekday:           slot[:weekday],
        sessions_per_week: sessions_per_week.to_i,
        time:              slot[:time],
        effective_from:    @effective_from
      )
    end
  end
end
