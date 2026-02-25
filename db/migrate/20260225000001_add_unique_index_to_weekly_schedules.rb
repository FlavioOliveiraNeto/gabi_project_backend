class AddUniqueIndexToWeeklySchedules < ActiveRecord::Migration[8.1]
  def change
    add_index :weekly_schedules,
              [:user_id, :weekday, :time],
              unique: true,
              name: "index_weekly_schedules_on_user_weekday_time"
  end
end
