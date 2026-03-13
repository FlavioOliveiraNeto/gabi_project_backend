class AddColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :active,               :boolean, default: true,  null: false
    add_column :users, :force_password_change, :boolean, default: false, null: false

    add_index :users, :active
  end
end
