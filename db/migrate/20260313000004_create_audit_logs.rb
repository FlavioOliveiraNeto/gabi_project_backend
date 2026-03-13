class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :user,        null: false, foreign_key: true
      t.string     :action,      null: false
      t.string     :entity_type, null: false
      t.bigint     :entity_id,   null: false
      t.jsonb      :metadata,    default: {}

      t.datetime :created_at, null: false
    end

    # user_id index already created by t.references above
    add_index :audit_logs, [ :entity_type, :entity_id ]
    add_index :audit_logs, :created_at
  end
end
