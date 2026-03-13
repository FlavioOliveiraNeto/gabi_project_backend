class FinalizeSessionsSchema < ActiveRecord::Migration[8.1]
  # Aplica as constraints que só são seguras após os backfills.
  # Remove o índice único legado em scheduled_at (substituído pela validação
  # de conflito no model Session).
  def up
    # NOT NULL em start_time / end_time — garantido pelo backfill 000007
    change_column_null :sessions, :start_time, false
    change_column_null :sessions, :end_time,   false

    # Remove o índice único legacy (user_id, scheduled_at, session_type).
    # A prevenção de conflitos agora é feita pela validação no model Session.
    if index_exists?(:sessions, %i[user_id scheduled_at session_type],
                     name: "index_sessions_on_user_id_scheduled_at_session_type")
      remove_index :sessions, name: "index_sessions_on_user_id_scheduled_at_session_type"
    end

    say "Constraints finais das sessions aplicadas."
  end

  def down
    change_column_null :sessions, :start_time, true
    change_column_null :sessions, :end_time,   true

    unless index_exists?(:sessions, %i[user_id scheduled_at session_type],
                         name: "index_sessions_on_user_id_scheduled_at_session_type")
      add_index :sessions, %i[user_id scheduled_at session_type],
                unique: true,
                name:   "index_sessions_on_user_id_scheduled_at_session_type"
    end
  end
end
