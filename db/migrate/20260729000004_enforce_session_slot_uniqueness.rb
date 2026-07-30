class EnforceSessionSlotUniqueness < ActiveRecord::Migration[8.1]
  def up
    add_reference :sessions, :therapist,
                  foreign_key: { to_table: :users, on_delete: :nullify },
                  index: false,
                  null: true

    execute(<<~SQL)
      UPDATE sessions
         SET therapist_id = users.therapist_id
        FROM users
       WHERE sessions.user_id = users.id
    SQL

    abort_on_duplicate_patient_sessions!
    abort_on_conflicting_scheduled_slots!

    add_index :sessions, [ :user_id, :scheduled_at, :session_type ],
              unique: true,
              name:   "index_sessions_on_user_scheduled_at_type"

    add_index :sessions, [ :therapist_id, :start_time ],
              unique: true,
              where:  "status = 0",
              name:   "index_sessions_on_therapist_scheduled_slot"
  end

  def down
    remove_index :sessions, name: "index_sessions_on_therapist_scheduled_slot"
    remove_index :sessions, name: "index_sessions_on_user_scheduled_at_type"
    remove_reference :sessions, :therapist, foreign_key: { to_table: :users }
  end

  private

  def abort_on_duplicate_patient_sessions!
    duplicates = select_rows(<<~SQL)
      SELECT user_id, scheduled_at, session_type, COUNT(*)
        FROM sessions
       WHERE scheduled_at IS NOT NULL
       GROUP BY user_id, scheduled_at, session_type
      HAVING COUNT(*) > 1
    SQL

    return if duplicates.empty?

    raise <<~MSG
      Existem #{duplicates.size} grupo(s) de sessões duplicadas em
      (user_id, scheduled_at, session_type), que impedem o índice único:

      #{duplicates.map { |r| "  user_id=#{r[0]} scheduled_at=#{r[1]} session_type=#{r[2]} (#{r[3]} linhas)" }.join("\n")}

      Resolva manualmente antes de migrar — não deduplico sessão automaticamente
      porque cada linha pode ter anotação clínica associada.
    MSG
  end

  def abort_on_conflicting_scheduled_slots!
    conflicts = select_rows(<<~SQL)
      SELECT therapist_id, start_time, COUNT(*)
        FROM sessions
       WHERE status = 0
         AND therapist_id IS NOT NULL
       GROUP BY therapist_id, start_time
      HAVING COUNT(*) > 1
    SQL

    return if conflicts.empty?

    raise <<~MSG
      Existem #{conflicts.size} slot(s) com mais de uma sessão agendada para a
      mesma terapeuta no mesmo horário:

      #{conflicts.map { |r| "  therapist_id=#{r[0]} start_time=#{r[1]} (#{r[2]} sessões)" }.join("\n")}

      Reagende pelo painel de conflitos antes de migrar.
    MSG
  end
end
