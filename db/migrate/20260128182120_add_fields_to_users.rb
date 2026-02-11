class AddFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_meet_link, :string
    add_column :users, :sessions_count, :integer, default: 0
  end
end
