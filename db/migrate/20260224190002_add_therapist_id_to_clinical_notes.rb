class AddTherapistIdToClinicalNotes < ActiveRecord::Migration[8.1]
  def up
    add_reference :clinical_notes, :therapist, null: true, foreign_key: { to_table: :users }

    # Retroalimenta therapist_id a partir da relação paciente → terapeuta
    execute <<-SQL
      UPDATE clinical_notes cn
      SET therapist_id = u.therapist_id
      FROM users u
      WHERE cn.user_id = u.id
        AND u.therapist_id IS NOT NULL
    SQL

    change_column_null :clinical_notes, :therapist_id, false
  end

  def down
    remove_reference :clinical_notes, :therapist
  end
end
