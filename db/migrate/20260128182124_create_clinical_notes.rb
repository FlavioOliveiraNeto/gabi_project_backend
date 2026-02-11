class CreateClinicalNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :clinical_notes do |t|
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.datetime :date

      t.timestamps
    end
  end
end
