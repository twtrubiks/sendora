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

ActiveRecord::Schema[8.1].define(version: 2026_06_13_040001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audiences", force: :cascade do |t|
    t.jsonb "conditions", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id"], name: "index_audiences_on_team_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.bigint "audience_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "error_message"
    t.string "name", null: false
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.string "subject", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["audience_id"], name: "index_campaigns_on_audience_id"
    t.index ["team_id"], name: "index_campaigns_on_team_id"
  end

  create_table "customer_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "tag_id"], name: "index_customer_tags_on_customer_id_and_tag_id", unique: true
    t.index ["customer_id"], name: "index_customer_tags_on_customer_id"
    t.index ["tag_id"], name: "index_customer_tags_on_tag_id"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "bounced_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "phone"
    t.bigint "team_id", null: false
    t.datetime "unsubscribed_at"
    t.datetime "updated_at", null: false
    t.index ["team_id", "email"], name: "index_customers_on_team_id_and_email", unique: true
    t.index ["team_id"], name: "index_customers_on_team_id"
  end

  create_table "deliveries", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "error_message"
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "customer_id"], name: "index_deliveries_on_campaign_id_and_customer_id", unique: true
    t.index ["campaign_id"], name: "index_deliveries_on_campaign_id"
    t.index ["customer_id"], name: "index_deliveries_on_customer_id"
    t.index ["team_id", "created_at"], name: "index_deliveries_on_team_id_and_created_at"
    t.index ["team_id"], name: "index_deliveries_on_team_id"
  end

  create_table "import_failures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "import_job_id", null: false
    t.integer "line_number", null: false
    t.string "message", null: false
    t.text "raw_row"
    t.datetime "updated_at", null: false
    t.index ["import_job_id"], name: "index_import_failures_on_import_job_id"
  end

  create_table "import_jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "error_message"
    t.integer "failure_count", default: 0, null: false
    t.string "filename", null: false
    t.integer "kind", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "success_count", default: 0, null: false
    t.bigint "team_id", null: false
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["team_id"], name: "index_import_jobs_on_team_id"
    t.index ["user_id"], name: "index_import_jobs_on_user_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["team_id", "user_id"], name: "index_memberships_on_team_id_and_user_id", unique: true
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.string "number", null: false
    t.datetime "ordered_at", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["team_id", "number"], name: "index_orders_on_team_id_and_number", unique: true
    t.index ["team_id"], name: "index_orders_on_team_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "name"], name: "index_tags_on_team_id_and_name", unique: true
    t.index ["team_id"], name: "index_tags_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "monthly_send_quota", default: 5000, null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_teams_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audiences", "teams"
  add_foreign_key "campaigns", "audiences"
  add_foreign_key "campaigns", "teams"
  add_foreign_key "customer_tags", "customers"
  add_foreign_key "customer_tags", "tags"
  add_foreign_key "customers", "teams"
  add_foreign_key "deliveries", "campaigns"
  add_foreign_key "deliveries", "customers"
  add_foreign_key "deliveries", "teams"
  add_foreign_key "import_failures", "import_jobs"
  add_foreign_key "import_jobs", "teams"
  add_foreign_key "import_jobs", "users"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "teams"
  add_foreign_key "sessions", "users"
  add_foreign_key "tags", "teams"
end
