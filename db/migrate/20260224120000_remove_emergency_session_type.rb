class RemoveEmergencySessionType < ActiveRecord::Migration[8.1]
  def up
    # Converte sessões do tipo emergency (2) para extra (1),
    # pois o tipo emergency foi removido da especificação.
    execute("UPDATE sessions SET session_type = 1 WHERE session_type = 2")
  end

  def down
    # Reversão não é possível com segurança: não há como
    # distinguir quais extras eram originalmente emergenciais.
    raise ActiveRecord::IrreversibleMigration
  end
end
