class BackfillClinicalNoteSessionId < ActiveRecord::Migration[8.1]
  # Vincula clinical_notes às sessions correspondentes.
  # Critério: mesmo user_id e mesma data (comparada no fuso America/Sao_Paulo).
  # Para notas que não têm sessão correspondente, cria uma sessão :extra :completed
  # como registro histórico, para que o NOT NULL possa ser aplicado com segurança.
  def up
    # ── 1. Vincular pelo par (user_id, date) ──────────────────────────────────
    execute <<~SQL
      UPDATE clinical_notes cn
      SET session_id = (
        SELECT s.id
        FROM sessions s
        WHERE s.user_id = cn.user_id
          AND DATE(s.start_time AT TIME ZONE 'America/Sao_Paulo')
              = DATE(cn.date AT TIME ZONE 'America/Sao_Paulo')
          AND s.status != 3
        ORDER BY s.start_time ASC
        LIMIT 1
      )
      WHERE cn.session_id IS NULL
        AND cn.date IS NOT NULL
    SQL

    orphans_with_date    = execute("SELECT COUNT(*) AS n FROM clinical_notes WHERE session_id IS NULL AND date IS NOT NULL").first["n"].to_i
    orphans_without_date = execute("SELECT COUNT(*) AS n FROM clinical_notes WHERE session_id IS NULL AND date IS NULL").first["n"].to_i
    say "Notas sem sessão após match por data: #{orphans_with_date} (com data) + #{orphans_without_date} (sem data)"

    # ── 2. Criar sessões-placeholder para notas orphãs com data ──────────────
    if orphans_with_date > 0
      execute <<~SQL
        INSERT INTO sessions (user_id, start_time, end_time, status, session_type, created_at, updated_at)
        SELECT DISTINCT
          cn.user_id,
          cn.date,
          cn.date + INTERVAL '50 minutes',
          1,
          1,
          NOW(),
          NOW()
        FROM clinical_notes cn
        WHERE cn.session_id IS NULL AND cn.date IS NOT NULL
      SQL

      execute <<~SQL
        UPDATE clinical_notes cn
        SET session_id = (
          SELECT s.id FROM sessions s
          WHERE s.user_id = cn.user_id AND s.start_time = cn.date
          ORDER BY s.id ASC LIMIT 1
        )
        WHERE cn.session_id IS NULL AND cn.date IS NOT NULL
      SQL
    end

    # ── 3. Criar sessão-placeholder genérica para notas sem data ─────────────
    if orphans_without_date > 0
      execute <<~SQL
        INSERT INTO sessions (user_id, start_time, end_time, status, session_type, created_at, updated_at)
        SELECT DISTINCT
          cn.user_id,
          NOW() - INTERVAL '2 years',
          NOW() - INTERVAL '2 years' + INTERVAL '50 minutes',
          1,
          1,
          NOW(),
          NOW()
        FROM clinical_notes cn
        WHERE cn.session_id IS NULL
      SQL

      execute <<~SQL
        UPDATE clinical_notes cn
        SET session_id = (
          SELECT s.id FROM sessions s
          WHERE s.user_id = cn.user_id
            AND s.start_time = NOW() - INTERVAL '2 years'
          ORDER BY s.id ASC LIMIT 1
        )
        WHERE cn.session_id IS NULL
      SQL
    end

    still_null = execute("SELECT COUNT(*) AS n FROM clinical_notes WHERE session_id IS NULL").first["n"].to_i
    raise "Ainda existem #{still_null} clinical_notes sem session_id após backfill." if still_null > 0

    # ── 4. Aplicar NOT NULL agora que todos os registros estão preenchidos ────
    change_column_null :clinical_notes, :session_id, false
    say "NOT NULL aplicado em clinical_notes.session_id"
  end

  def down
    change_column_null :clinical_notes, :session_id, true
    execute "UPDATE clinical_notes SET session_id = NULL"
  end
end
