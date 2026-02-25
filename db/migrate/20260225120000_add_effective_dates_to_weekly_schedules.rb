class AddEffectiveDatesToWeeklySchedules < ActiveRecord::Migration[8.1]
  def up
    add_column :weekly_schedules, :effective_from, :date
    add_column :weekly_schedules, :effective_until, :date

    # Backfill: registros existentes recebem a data de criação como effective_from.
    # Preserva semântica: "esse schedule estava ativo desde que foi criado".
    execute <<~SQL
      UPDATE weekly_schedules
      SET effective_from = DATE(created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Sao_Paulo')
    SQL

    # Agora que todos têm valor, aplica o NOT NULL
    change_column_null :weekly_schedules, :effective_from, false

    # Remove o índice antigo — ele proibia mesmo weekday+time para o mesmo user,
    # o que agora é válido em períodos históricos diferentes.
    remove_index :weekly_schedules, name: "index_weekly_schedules_on_user_weekday_time"

    # Novo índice: impede dois schedules para o mesmo paciente, mesmo dia da semana
    # e mesma data de início. Permite histórico de diferentes períodos.
    add_index :weekly_schedules,
              %i[user_id weekday effective_from],
              unique: true,
              name: "index_weekly_schedules_on_user_weekday_effective_from"
  end

  def down
    remove_index :weekly_schedules, name: "index_weekly_schedules_on_user_weekday_effective_from"

    add_index :weekly_schedules,
              %i[user_id weekday time],
              unique: true,
              name: "index_weekly_schedules_on_user_weekday_time"

    remove_column :weekly_schedules, :effective_until
    remove_column :weekly_schedules, :effective_from
  end
end
