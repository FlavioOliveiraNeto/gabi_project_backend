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

ActiveRecord::Schema[8.1].define(version: 2026_02_24_190002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "clinical_notes", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "date"
    t.bigint "therapist_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
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

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "scheduled_at", null: false
    t.integer "session_type", default: 0, null: false
    t.integer "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "scheduled_at", "session_type"], name: "index_sessions_on_user_id_scheduled_at_session_type", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["therapist_id"], name: "index_users_on_therapist_id"
  end

  create_table "weekly_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "sessions_per_week"
    t.string "time"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "weekday"
    t.index ["user_id"], name: "index_weekly_schedules_on_user_id"
  end

  add_foreign_key "clinical_notes", "users"
  add_foreign_key "clinical_notes", "users", column: "therapist_id"
  add_foreign_key "patient_notes", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "users", column: "therapist_id"
  add_foreign_key "weekly_schedules", "users"
end
