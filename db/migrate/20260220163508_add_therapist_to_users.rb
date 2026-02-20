class AddTherapistToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :therapist, null: true, foreign_key: { to_table: :users }
  end
end
