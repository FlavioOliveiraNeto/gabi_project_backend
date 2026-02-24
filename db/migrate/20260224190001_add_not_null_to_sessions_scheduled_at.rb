class AddNotNullToSessionsScheduledAt < ActiveRecord::Migration[8.1]
  def up
    # Remove qualquer sessão sem data antes de aplicar a constraint
    execute "DELETE FROM sessions WHERE scheduled_at IS NULL"
    change_column_null :sessions, :scheduled_at, false
  end

  def down
    change_column_null :sessions, :scheduled_at, true
  end
end
