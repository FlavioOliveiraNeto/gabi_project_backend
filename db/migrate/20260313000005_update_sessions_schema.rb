class UpdateSessionsSchema < ActiveRecord::Migration[8.1]
  def change
    # Adiciona FK para recurring_schedule (nullable — sessão extra não tem)
    add_reference :sessions, :recurring_schedule, null: true, foreign_key: true

    # Novos campos de horário explícito (substituem scheduled_at)
    add_column :sessions, :start_time, :datetime
    add_column :sessions, :end_time,   :datetime

    add_column :sessions, :meet_link,  :string

    # Remove a restrição NOT NULL de scheduled_at para evitar quebrar dados
    # existentes durante a transição. A remoção definitiva fica para uma
    # migration de limpeza após a migração de dados.
    change_column_null :sessions, :scheduled_at, true

    # recurring_schedule_id index created by add_reference above
    add_index :sessions, :start_time
  end
end
