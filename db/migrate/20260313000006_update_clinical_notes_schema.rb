class UpdateClinicalNotesSchema < ActiveRecord::Migration[8.1]
  def change
    # session_id adicionado NULLABLE aqui para não travar em produção com dados existentes.
    # O NOT NULL é aplicado em 20260313000009 após o backfill de dados.
    add_reference :clinical_notes, :session, null: true, foreign_key: true

    # therapist_id e date passam a ser opcionais (mantidos para dados legados)
    change_column_null :clinical_notes, :therapist_id, true
    change_column_null :clinical_notes, :date, true
  end
end
