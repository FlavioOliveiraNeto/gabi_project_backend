class SessionGeneratorService
  def initialize(user)
    @user = user
  end

  def generate_for_next_month
    schedules = @user.weekly_schedules

    schedules.each do |schedule|
      generate_for_schedule(schedule)
    end
  end

  private

  def generate_for_schedule(schedule)
    today = Date.current
    end_date = today + 1.month

    (today..end_date).each do |date|
      next unless date.wday == WeeklySchedule.weekdays[schedule.weekday]

      datetime = Time.zone.parse("#{date} #{schedule.time}")

      @user.sessions.find_or_create_by!(
        scheduled_at: datetime,
        status: :scheduled
      )
    end
  end
end