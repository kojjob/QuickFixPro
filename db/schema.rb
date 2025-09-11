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

ActiveRecord::Schema[8.0].define(version: 2025_09_10_113914) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.integer "status", default: 0, null: false
    t.uuid "created_by_id"
    t.jsonb "settings", default: {}
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_accounts_on_created_by_id"
    t.index ["settings"], name: "index_accounts_on_settings", using: :gin
    t.index ["status"], name: "index_accounts_on_status"
    t.index ["subdomain"], name: "index_accounts_on_subdomain", unique: true
  end

  create_table "audit_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "website_id", null: false
    t.uuid "triggered_by_id"
    t.integer "overall_score"
    t.integer "audit_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.decimal "duration", precision: 8, scale: 3
    t.text "error_message"
    t.jsonb "raw_results", default: {}
    t.jsonb "summary_data", default: {}
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_type"], name: "index_audit_reports_on_audit_type"
    t.index ["overall_score"], name: "index_audit_reports_on_overall_score"
    t.index ["raw_results"], name: "index_audit_reports_on_raw_results", using: :gin
    t.index ["status"], name: "index_audit_reports_on_status"
    t.index ["summary_data"], name: "index_audit_reports_on_summary_data", using: :gin
    t.index ["triggered_by_id"], name: "index_audit_reports_on_triggered_by_id"
    t.index ["website_id", "created_at"], name: "index_audit_reports_on_website_id_and_created_at"
    t.index ["website_id", "status"], name: "index_audit_reports_on_website_id_and_status"
    t.index ["website_id"], name: "index_audit_reports_on_website_id"
  end

  create_table "optimization_recommendations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "audit_report_id", null: false
    t.uuid "website_id", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.integer "priority", default: 0, null: false
    t.string "estimated_savings"
    t.integer "status", default: 0, null: false
    t.string "category"
    t.text "implementation_guide"
    t.string "difficulty_level", default: "medium"
    t.decimal "potential_score_improvement", precision: 5, scale: 2
    t.jsonb "resources", default: []
    t.boolean "automated_fix_available", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_report_id"], name: "index_optimization_recommendations_on_audit_report_id"
    t.index ["category"], name: "index_optimization_recommendations_on_category"
    t.index ["priority"], name: "index_optimization_recommendations_on_priority"
    t.index ["resources"], name: "index_optimization_recommendations_on_resources", using: :gin
    t.index ["status"], name: "index_optimization_recommendations_on_status"
    t.index ["website_id", "priority"], name: "index_optimization_recommendations_on_website_id_and_priority"
    t.index ["website_id", "status"], name: "index_optimization_recommendations_on_website_id_and_status"
    t.index ["website_id"], name: "index_optimization_recommendations_on_website_id"
  end

  create_table "performance_metrics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "audit_report_id", null: false
    t.uuid "website_id", null: false
    t.string "metric_type", null: false
    t.decimal "value", precision: 10, scale: 3, null: false
    t.string "unit", default: "ms"
    t.integer "threshold_status", default: 0, null: false
    t.decimal "threshold_good", precision: 10, scale: 3
    t.decimal "threshold_poor", precision: 10, scale: 3
    t.integer "score_contribution"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_report_id"], name: "index_performance_metrics_on_audit_report_id"
    t.index ["metadata"], name: "index_performance_metrics_on_metadata", using: :gin
    t.index ["metric_type"], name: "index_performance_metrics_on_metric_type"
    t.index ["threshold_status"], name: "index_performance_metrics_on_threshold_status"
    t.index ["website_id", "created_at"], name: "index_performance_metrics_on_website_id_and_created_at"
    t.index ["website_id", "metric_type"], name: "index_performance_metrics_on_website_id_and_metric_type"
    t.index ["website_id"], name: "index_performance_metrics_on_website_id"
  end

  create_table "subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "plan_name", null: false
    t.integer "status", default: 0, null: false
    t.decimal "monthly_price", precision: 8, scale: 2
    t.jsonb "usage_limits", default: {}
    t.datetime "trial_ends_at"
    t.datetime "billing_cycle_started_at"
    t.datetime "cancelled_at"
    t.string "external_subscription_id"
    t.jsonb "plan_features", default: {}
    t.jsonb "current_usage", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriptions_on_account_id"
    t.index ["current_usage"], name: "index_subscriptions_on_current_usage", using: :gin
    t.index ["external_subscription_id"], name: "index_subscriptions_on_external_subscription_id", unique: true
    t.index ["plan_features"], name: "index_subscriptions_on_plan_features", using: :gin
    t.index ["plan_name"], name: "index_subscriptions_on_plan_name"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["trial_ends_at"], name: "index_subscriptions_on_trial_ends_at"
    t.index ["usage_limits"], name: "index_subscriptions_on_usage_limits", using: :gin
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.uuid "account_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.integer "role", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.jsonb "preferences", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_users_on_account_id_and_email", unique: true
    t.index ["account_id", "role"], name: "index_users_on_account_id_and_role"
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["preferences"], name: "index_users_on_preferences", using: :gin
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "websites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.integer "status", default: 0, null: false
    t.integer "monitoring_frequency", default: 0, null: false
    t.uuid "account_id", null: false
    t.uuid "created_by_id", null: false
    t.text "description"
    t.jsonb "monitoring_settings", default: {}
    t.datetime "last_monitored_at"
    t.integer "current_score"
    t.boolean "alerts_enabled", default: true
    t.jsonb "notification_settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "public_showcase", default: false, null: false
    t.index ["account_id", "name"], name: "index_websites_on_account_id_and_name"
    t.index ["account_id", "status"], name: "index_websites_on_account_id_and_status"
    t.index ["account_id", "url"], name: "index_websites_on_account_id_and_url", unique: true
    t.index ["account_id"], name: "index_websites_on_account_id"
    t.index ["created_by_id"], name: "index_websites_on_created_by_id"
    t.index ["last_monitored_at"], name: "index_websites_on_last_monitored_at"
    t.index ["monitoring_frequency"], name: "index_websites_on_monitoring_frequency"
    t.index ["monitoring_settings"], name: "index_websites_on_monitoring_settings", using: :gin
    t.index ["notification_settings"], name: "index_websites_on_notification_settings", using: :gin
    t.index ["public_showcase"], name: "index_websites_on_public_showcase"
  end

  add_foreign_key "audit_reports", "users", column: "triggered_by_id"
  add_foreign_key "audit_reports", "websites"
  add_foreign_key "optimization_recommendations", "audit_reports"
  add_foreign_key "optimization_recommendations", "websites"
  add_foreign_key "performance_metrics", "audit_reports"
  add_foreign_key "performance_metrics", "websites"
  add_foreign_key "subscriptions", "accounts"
  add_foreign_key "users", "accounts"
  add_foreign_key "websites", "accounts"
  add_foreign_key "websites", "users", column: "created_by_id"
end
