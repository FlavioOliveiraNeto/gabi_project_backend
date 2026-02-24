class AddUniqueIndexToSessions < ActiveRecord::Migration[8.1]
  def change
    add_index :sessions, %i[user_id scheduled_at session_type], unique: true,
              name: "index_sessions_on_user_id_scheduled_at_session_type"
  end
end
