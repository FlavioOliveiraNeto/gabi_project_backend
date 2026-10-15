class AddUniqueIndexToClinicalNotesSession < ActiveRecord::Migration[8.1]
  # A validação de unicidade do model não segura dois POSTs simultâneos.
  def change
    remove_index :clinical_notes, :session_id
    add_index :clinical_notes, :session_id, unique: true
  end
end
