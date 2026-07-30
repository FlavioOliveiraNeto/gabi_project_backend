class HardenJwtDenylistsJti < ActiveRecord::Migration[8.1]
  def up
    execute("DELETE FROM jwt_denylists WHERE jti IS NULL")

    execute(<<~SQL)
      DELETE FROM jwt_denylists
      WHERE id NOT IN (SELECT MAX(id) FROM jwt_denylists GROUP BY jti)
    SQL

    change_column_null :jwt_denylists, :jti, false

    remove_index :jwt_denylists, :jti
    add_index    :jwt_denylists, :jti, unique: true
  end

  def down
    remove_index :jwt_denylists, :jti
    add_index    :jwt_denylists, :jti
    change_column_null :jwt_denylists, :jti, true
  end
end
