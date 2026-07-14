class CreateRecurringSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_schedules do |t|
      t.references :user,            null: false, foreign_key: true
      t.integer    :weekday,         null: false
      t.time       :start_time,      null: false
      t.integer    :duration_minutes, null: false
      t.string     :meet_link
      t.boolean    :active,          null: false, default: true

      t.timestamps
    end

    add_index :recurring_schedules, [ :user_id, :weekday, :active ]
  end
end
