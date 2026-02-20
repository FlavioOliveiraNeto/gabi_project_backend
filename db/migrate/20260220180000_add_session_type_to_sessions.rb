class AddSessionTypeToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :session_type, :integer, default: 0, null: false
  end
end
