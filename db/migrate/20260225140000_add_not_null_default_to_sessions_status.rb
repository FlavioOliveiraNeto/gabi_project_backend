class AddNotNullDefaultToSessionsStatus < ActiveRecord::Migration[8.1]
  def up
    # Garante que nenhum registro fique com status NULL antes de aplicar a constraint
    execute "UPDATE sessions SET status = 0 WHERE status IS NULL"

    change_column_default :sessions, :status, from: nil, to: 0
    change_column_null    :sessions, :status, false
  end

  def down
    change_column_null    :sessions, :status, true
    change_column_default :sessions, :status, from: 0, to: nil
  end
end
