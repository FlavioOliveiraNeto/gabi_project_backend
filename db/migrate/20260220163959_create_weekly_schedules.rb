class CreateWeeklySchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :weekly_schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :weekday
      t.string :time
      t.integer :sessions_per_week

      t.timestamps
    end
  end
end
