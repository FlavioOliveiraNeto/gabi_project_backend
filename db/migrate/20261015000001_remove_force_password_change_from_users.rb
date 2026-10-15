class RemoveForcePasswordChangeFromUsers < ActiveRecord::Migration[8.1]
  # Coluna morta: must_change_password é a única fonte de verdade.
  def change
    remove_column :users, :force_password_change, :boolean, default: false, null: false
  end
end
