class AddPaidToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :paid, :boolean, default: false, null: false
  end
end
