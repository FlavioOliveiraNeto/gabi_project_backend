class CreatePatientNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :patient_notes do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content

      t.timestamps
    end
  end
end
