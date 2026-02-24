class RemoveSessionsCountFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :sessions_count, :integer
  end
end
