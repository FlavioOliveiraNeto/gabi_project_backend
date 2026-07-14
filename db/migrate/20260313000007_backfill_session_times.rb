class BackfillSessionTimes < ActiveRecord::Migration[8.1]
  # Preenche start_time e end_time a partir de scheduled_at.
  # A duração default é 50 minutos — mesma usada historicamente pelo sistema.
  # Deve rodar APÓS 20260313000005 (que adicionou as colunas como nullable).
  def up
    execute <<~SQL
      UPDATE sessions
      SET
        start_time = scheduled_at,
        end_time   = scheduled_at + INTERVAL '50 minutes'
      WHERE start_time IS NULL
        AND scheduled_at IS NOT NULL
    SQL

    orphans = execute("SELECT COUNT(*) AS n FROM sessions WHERE start_time IS NULL").first["n"].to_i
    raise "Ainda existem #{orphans} sessões sem start_time após backfill." if orphans > 0
  end

  def down
    execute "UPDATE sessions SET start_time = NULL, end_time = NULL"
  end
end
