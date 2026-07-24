# frozen_string_literal: true

class AddTherapistToCalendarBlocks < ActiveRecord::Migration[8.1]
  def up
    add_reference :calendar_blocks, :therapist, foreign_key: { to_table: :users }, index: true

    # Backfill: no design single-therapist todo bloqueio pertence à (única)
    # terapeuta existente. Se houver mais de uma, não há como inferir o dono -
    # falha explícita para revisão manual em vez de atribuir errado.
    therapist_ids = select_values("SELECT id FROM users WHERE role = 0")
    if select_value("SELECT COUNT(*) FROM calendar_blocks").to_i.positive?
      raise "Backfill ambíguo: múltiplas terapeutas para calendar_blocks existentes" if therapist_ids.size > 1

      execute("UPDATE calendar_blocks SET therapist_id = #{therapist_ids.first}") if therapist_ids.size == 1
    end

    change_column_null :calendar_blocks, :therapist_id, false
  end

  def down
    remove_reference :calendar_blocks, :therapist, foreign_key: { to_table: :users }
  end
end
