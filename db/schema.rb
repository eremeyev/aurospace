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

ActiveRecord::Schema[8.1].define(version: 2026_04_23_215050) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.string "notes"
    t.bigint "payment_account_id"
    t.datetime "processed_at"
    t.integer "status", default: 0, null: false
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_orders_on_idempotency_key", unique: true
    t.index ["payment_account_id", "status"], name: "index_orders_on_payment_account_id_and_status"
    t.index ["payment_account_id"], name: "index_orders_on_payment_account_id"
  end

  create_table "payment_accounts", force: :cascade do |t|
    t.integer "account_type", default: 0
    t.decimal "balance", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "ÚSD", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_payment_accounts_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "balance_after", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.bigint "order_id", null: false
    t.bigint "payment_account_id", null: false
    t.integer "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_transactions_on_order_id"
    t.index ["payment_account_id", "created_at"], name: "index_transactions_on_payment_account_id_and_created_at", order: { created_at: :desc }
    t.index ["payment_account_id"], name: "index_transactions_on_payment_account_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "api_token", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "role", default: 0
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "orders", "payment_accounts"
  add_foreign_key "payment_accounts", "users"
  add_foreign_key "transactions", "orders"
  add_foreign_key "transactions", "payment_accounts"
end
