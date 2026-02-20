class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :scheduled_at
      t.integer :status

      t.timestamps
    end
  end
end
