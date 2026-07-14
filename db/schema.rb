# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_13_000010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.string "entity_type", null: false
    t.jsonb "metadata", default: {}
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["entity_type", "entity_id"], name: "index_audit_logs_on_entity_type_and_entity_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "calendar_blocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_time", null: false
    t.string "reason", null: false
    t.datetime "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["start_time"], name: "index_calendar_blocks_on_start_time"
  end

  create_table "clinical_notes", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "date"
    t.bigint "session_id", null: false
    t.bigint "therapist_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["session_id"], name: "index_clinical_notes_on_session_id"
    t.index ["therapist_id"], name: "index_clinical_notes_on_therapist_id"
    t.index ["user_id"], name: "index_clinical_notes_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp"
    t.string "jti"
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "patient_notes", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_patient_notes_on_user_id"
  end

  create_table "recurring_schedules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes", null: false
    t.string "meet_link"
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "weekday", null: false
    t.index ["user_id", "weekday", "active"], name: "index_recurring_schedules_on_user_id_and_weekday_and_active"
    t.index ["user_id"], name: "index_recurring_schedules_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_time", null: false
    t.string "meet_link"
    t.bigint "recurring_schedule_id"
    t.datetime "scheduled_at"
    t.integer "session_type", default: 0, null: false
    t.datetime "start_time", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["recurring_schedule_id"], name: "index_sessions_on_recurring_schedule_id"
    t.index ["start_time"], name: "index_sessions_on_start_time"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "force_password_change", default: false, null: false
    t.string "google_meet_link"
    t.boolean "must_change_password", default: false, null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.bigint "therapist_id"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["therapist_id"], name: "index_users_on_therapist_id"
  end

  create_table "weekly_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "effective_from", null: false
    t.date "effective_until"
    t.integer "sessions_per_week"
    t.string "time"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "weekday"
    t.index ["user_id", "weekday", "effective_from"], name: "index_weekly_schedules_on_user_weekday_effective_from", unique: true
    t.index ["user_id"], name: "index_weekly_schedules_on_user_id"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "clinical_notes", "sessions"
  add_foreign_key "clinical_notes", "users"
  add_foreign_key "clinical_notes", "users", column: "therapist_id"
  add_foreign_key "patient_notes", "users"
  add_foreign_key "recurring_schedules", "users"
  add_foreign_key "sessions", "recurring_schedules"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "users", column: "therapist_id"
  add_foreign_key "weekly_schedules", "users"
end
