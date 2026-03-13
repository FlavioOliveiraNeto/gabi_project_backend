class MigrateWeeklyToRecurringSchedules < ActiveRecord::Migration[8.1]
  # Converte weekly_schedules (legado) em recurring_schedules (novo design).
  # Para cada cliente, pega o weekly_schedule mais recente por dia da semana.
  # Depois vincula as sessions :recurring ao recurring_schedule correspondente.
  def up
    # ── 1. Criar recurring_schedules a partir das agendas semanais ─────────────
    execute <<~SQL
      INSERT INTO recurring_schedules
        (user_id, weekday, start_time, duration_minutes, meet_link, active, created_at, updated_at)
      SELECT DISTINCT ON (ws.user_id, ws.weekday)
        ws.user_id,
        ws.weekday,
        ws.time::time,
        50,
        u.google_meet_link,
        (ws.effective_until IS NULL OR ws.effective_until >= CURRENT_DATE),
        NOW(),
        NOW()
      FROM weekly_schedules ws
      JOIN users u ON u.id = ws.user_id
      ORDER BY ws.user_id, ws.weekday, ws.effective_from DESC
    SQL

    rs_count = execute("SELECT COUNT(*) AS n FROM recurring_schedules").first["n"]
    say "recurring_schedules criados: #{rs_count}"

    # ── 2. Vincular sessions :recurring ao recurring_schedule correspondente ───
    # Usa o dia da semana e horário da sessão para encontrar o schedule.
    execute <<~SQL
      UPDATE sessions s
      SET recurring_schedule_id = rs.id
      FROM recurring_schedules rs
      WHERE s.session_type = 0
        AND s.recurring_schedule_id IS NULL
        AND s.user_id = rs.user_id
        AND EXTRACT(DOW FROM s.start_time AT TIME ZONE 'America/Sao_Paulo')::int = rs.weekday
        AND (s.start_time AT TIME ZONE 'America/Sao_Paulo')::time = rs.start_time
    SQL

    linked = execute("SELECT COUNT(*) AS n FROM sessions WHERE session_type = 0 AND recurring_schedule_id IS NOT NULL").first["n"]
    unlinked = execute("SELECT COUNT(*) AS n FROM sessions WHERE session_type = 0 AND recurring_schedule_id IS NULL").first["n"]
    say "Sessões recorrentes vinculadas: #{linked} | sem vínculo: #{unlinked}"

    # ── 3. Sincronizar force_password_change ← must_change_password ───────────
    execute "UPDATE users SET force_password_change = must_change_password"
    say "force_password_change sincronizado"
  end

  def down
    execute "UPDATE sessions SET recurring_schedule_id = NULL"
    execute "DELETE FROM recurring_schedules"
    execute "UPDATE users SET force_password_change = false"
  end
end
