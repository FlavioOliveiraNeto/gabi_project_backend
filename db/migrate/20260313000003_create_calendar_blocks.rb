class CreateCalendarBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_blocks do |t|
      t.datetime :start_time, null: false
      t.datetime :end_time,   null: false
      t.string   :reason,     null: false

      t.timestamps
    end

    add_index :calendar_blocks, :start_time
  end
end
