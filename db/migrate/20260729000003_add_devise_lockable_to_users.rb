class AddDeviseLockableToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.integer  :failed_attempts, null: false, default: 0
      t.string   :unlock_token
      t.datetime :locked_at
    end

    add_index :users, :unlock_token, unique: true
  end
end
