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

ActiveRecord::Schema[8.0].define(version: 2026_09_14_120030) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activity_events", force: :cascade do |t|
    t.bigint "group_id"
    t.bigint "actor_id"
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "action", null: false
    t.string "summary", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_activity_events_on_action"
    t.index ["actor_id"], name: "index_activity_events_on_actor_id"
    t.index ["group_id", "occurred_at"], name: "index_activity_events_on_group_id_and_occurred_at"
    t.index ["group_id"], name: "index_activity_events_on_group_id"
    t.index ["occurred_at"], name: "index_activity_events_on_occurred_at"
    t.index ["subject_type", "subject_id"], name: "index_activity_events_on_subject"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "icon", default: "receipt", null: false
    t.string "color", default: "ink", null: false
    t.integer "position", default: 100, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_categories_on_active"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "currencies", primary_key: "code", id: { type: :string, limit: 3 }, force: :cascade do |t|
    t.string "name", null: false
    t.string "symbol", null: false
    t.integer "exponent", default: 2, null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 100, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_currencies_on_active"
    t.check_constraint "code::text = upper(code::text)", name: "currencies_code_uppercase"
    t.check_constraint "exponent >= 0 AND exponent <= 4", name: "currencies_exponent_range"
  end

  create_table "exchange_rates", force: :cascade do |t|
    t.string "base_currency_code", limit: 3, null: false
    t.string "quote_currency_code", limit: 3, null: false
    t.decimal "rate", precision: 24, scale: 12, null: false
    t.date "rate_date", null: false
    t.string "source", default: "manual", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["base_currency_code", "quote_currency_code", "rate_date"], name: "index_exchange_rates_on_pair_and_date", unique: true
    t.check_constraint "rate > 0::numeric", name: "exchange_rates_positive"
  end

  create_table "expense_participants", force: :cascade do |t|
    t.bigint "expense_id", null: false
    t.bigint "user_id", null: false
    t.decimal "split_value", precision: 20, scale: 6
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id", "user_id"], name: "index_expense_participants_on_expense_id_and_user_id", unique: true
    t.index ["expense_id"], name: "index_expense_participants_on_expense_id"
    t.index ["user_id", "expense_id"], name: "index_expense_participants_on_user_id_and_expense_id"
    t.index ["user_id"], name: "index_expense_participants_on_user_id"
    t.check_constraint "split_value IS NULL OR split_value >= 0::numeric", name: "expense_participants_split_value_non_negative"
  end

  create_table "expense_payers", force: :cascade do |t|
    t.bigint "expense_id", null: false
    t.bigint "user_id", null: false
    t.bigint "amount_minor", null: false
    t.bigint "base_amount_minor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id", "user_id"], name: "index_expense_payers_on_expense_id_and_user_id", unique: true
    t.index ["expense_id"], name: "index_expense_payers_on_expense_id"
    t.index ["user_id", "expense_id"], name: "index_expense_payers_on_user_id_and_expense_id"
    t.index ["user_id"], name: "index_expense_payers_on_user_id"
    t.check_constraint "amount_minor > 0", name: "expense_payers_amount_positive"
  end

  create_table "expense_splits", force: :cascade do |t|
    t.bigint "expense_id", null: false
    t.bigint "user_id", null: false
    t.bigint "amount_minor", null: false
    t.bigint "base_amount_minor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id", "user_id"], name: "index_expense_splits_on_expense_id_and_user_id", unique: true
    t.index ["expense_id"], name: "index_expense_splits_on_expense_id"
    t.index ["user_id", "expense_id"], name: "index_expense_splits_on_user_id_and_expense_id"
    t.index ["user_id"], name: "index_expense_splits_on_user_id"
    t.check_constraint "amount_minor >= 0", name: "expense_splits_amount_non_negative"
  end

  create_table "expenses", force: :cascade do |t|
    t.bigint "group_id"
    t.bigint "category_id"
    t.bigint "created_by_id"
    t.string "description", null: false
    t.text "notes"
    t.string "currency_code", limit: 3, null: false
    t.bigint "amount_minor", null: false
    t.string "base_currency_code", limit: 3, null: false
    t.decimal "exchange_rate", precision: 24, scale: 12, default: "1.0", null: false
    t.bigint "base_amount_minor", null: false
    t.date "spent_on", null: false
    t.time "spent_time"
    t.string "split_method", default: "equal", null: false
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.string "void_reason"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "rate_locked_at"
    t.string "rate_source", default: "indicative", null: false
    t.bigint "rate_locked_by_id"
    t.bigint "owner_id"
    t.index ["category_id"], name: "index_expenses_on_category_id"
    t.index ["created_by_id"], name: "index_expenses_on_created_by_id"
    t.index ["currency_code"], name: "index_expenses_on_currency_code"
    t.index ["group_id", "rate_locked_at"], name: "index_expenses_on_group_id_and_rate_locked_at"
    t.index ["group_id", "spent_on"], name: "index_expenses_on_group_id_and_spent_on"
    t.index ["group_id", "voided_at"], name: "index_expenses_on_group_id_and_voided_at"
    t.index ["group_id"], name: "index_expenses_on_group_id"
    t.index ["owner_id", "spent_on"], name: "index_expenses_on_owner_id_and_spent_on"
    t.index ["owner_id"], name: "index_expenses_on_owner_id"
    t.index ["rate_locked_by_id"], name: "index_expenses_on_rate_locked_by_id"
    t.index ["spent_on"], name: "index_expenses_on_spent_on"
    t.index ["voided_at"], name: "index_expenses_on_voided_at"
    t.index ["voided_by_id"], name: "index_expenses_on_voided_by_id"
    t.check_constraint "amount_minor > 0", name: "expenses_amount_positive"
    t.check_constraint "base_amount_minor > 0", name: "expenses_base_amount_positive"
    t.check_constraint "exchange_rate > 0::numeric", name: "expenses_rate_positive"
    t.check_constraint "group_id IS NOT NULL OR owner_id IS NOT NULL", name: "expenses_have_a_home"
    t.check_constraint "length(btrim(description::text)) > 0", name: "expenses_description_present"
    t.check_constraint "rate_source::text = ANY (ARRAY['indicative'::character varying::text, 'locked'::character varying::text, 'native'::character varying::text])", name: "expenses_rate_source_valid"
    t.check_constraint "split_method::text = ANY (ARRAY['equal'::character varying::text, 'percentage'::character varying::text, 'fixed'::character varying::text, 'shares'::character varying::text])", name: "expenses_split_method_valid"
  end

  create_table "friendships", force: :cascade do |t|
    t.bigint "requester_id", null: false
    t.bigint "addressee_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["addressee_id", "status"], name: "index_friendships_on_addressee_id_and_status"
    t.index ["addressee_id"], name: "index_friendships_on_addressee_id"
    t.index ["requester_id", "addressee_id"], name: "index_friendships_on_requester_id_and_addressee_id", unique: true
    t.index ["requester_id"], name: "index_friendships_on_requester_id"
    t.check_constraint "requester_id <> addressee_id", name: "friendships_distinct_people"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying]::text[])", name: "friendships_status_valid"
  end

  create_table "group_memberships", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "user_id", null: false
    t.datetime "joined_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "user_id"], name: "index_group_memberships_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["user_id", "group_id"], name: "index_group_memberships_on_user_id_and_group_id"
    t.index ["user_id"], name: "index_group_memberships_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "base_currency_code", limit: 3, default: "PHP", null: false
    t.bigint "created_by_id"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["base_currency_code"], name: "index_groups_on_base_currency_code"
    t.index ["created_by_id"], name: "index_groups_on_created_by_id"
    t.check_constraint "length(btrim(name::text)) > 0", name: "groups_name_present"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "created_by_id"
    t.bigint "group_id"
    t.datetime "revoked_at"
    t.datetime "expires_at"
    t.integer "accepted_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_uses"
    t.index ["created_by_id", "revoked_at"], name: "index_invitations_on_created_by_id_and_revoked_at"
    t.index ["created_by_id"], name: "index_invitations_on_created_by_id"
    t.index ["group_id"], name: "index_invitations_on_group_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.check_constraint "max_uses IS NULL OR max_uses > 0", name: "invitations_max_uses_positive"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.bigint "group_id"
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "kind", null: false
    t.string "title", null: false
    t.string "body"
    t.string "url"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["group_id"], name: "index_notifications_on_group_id"
    t.index ["subject_type", "subject_id"], name: "index_notifications_on_subject"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at", "created_at"], name: "index_notifications_on_user_and_state"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "recovery_codes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "code_digest", null: false
    t.integer "position", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_digest"], name: "index_recovery_codes_on_code_digest", unique: true
    t.index ["user_id", "position"], name: "index_recovery_codes_on_user_id_and_position", unique: true
    t.index ["user_id", "used_at"], name: "index_recovery_codes_on_user_id_and_used_at"
    t.index ["user_id"], name: "index_recovery_codes_on_user_id"
  end

  create_table "revisions", force: :cascade do |t|
    t.string "revisable_type", null: false
    t.bigint "revisable_id", null: false
    t.bigint "actor_id"
    t.integer "revision_number", null: false
    t.string "action", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.jsonb "changed_fields", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_revisions_on_actor_id"
    t.index ["revisable_type", "revisable_id", "revision_number"], name: "index_revisions_on_revisable_and_number", unique: true
    t.index ["revisable_type", "revisable_id"], name: "index_revisions_on_revisable"
  end

  create_table "settlements", force: :cascade do |t|
    t.bigint "group_id"
    t.bigint "payer_id", null: false
    t.bigint "recipient_id", null: false
    t.bigint "created_by_id"
    t.string "currency_code", limit: 3, null: false
    t.bigint "amount_minor", null: false
    t.string "base_currency_code", limit: 3, null: false
    t.decimal "exchange_rate", precision: 24, scale: 12, default: "1.0", null: false
    t.bigint "base_amount_minor", null: false
    t.date "settled_on", null: false
    t.string "payment_method"
    t.text "note"
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "settles_currency_code", limit: 3
    t.index ["created_by_id"], name: "index_settlements_on_created_by_id"
    t.index ["group_id", "settled_on"], name: "index_settlements_on_group_id_and_settled_on"
    t.index ["group_id"], name: "index_settlements_on_group_id"
    t.index ["payer_id", "recipient_id", "settled_on"], name: "index_settlements_on_pair_and_date"
    t.index ["payer_id", "recipient_id"], name: "index_settlements_on_payer_id_and_recipient_id"
    t.index ["payer_id"], name: "index_settlements_on_payer_id"
    t.index ["recipient_id"], name: "index_settlements_on_recipient_id"
    t.index ["settled_on"], name: "index_settlements_on_settled_on"
    t.index ["settles_currency_code"], name: "index_settlements_on_settles_currency_code"
    t.index ["voided_at"], name: "index_settlements_on_voided_at"
    t.index ["voided_by_id"], name: "index_settlements_on_voided_by_id"
    t.check_constraint "amount_minor > 0", name: "settlements_amount_positive"
    t.check_constraint "base_amount_minor > 0", name: "settlements_base_amount_positive"
    t.check_constraint "exchange_rate > 0::numeric", name: "settlements_rate_positive"
    t.check_constraint "payer_id <> recipient_id", name: "settlements_distinct_parties"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.date "date_of_birth"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "preferred_currency_code", limit: 3, default: "PHP", null: false
    t.datetime "archived_at"
    t.integer "archived_ordinal"
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "last_sign_in_at"
    t.datetime "recovery_codes_generated_at"
    t.string "username", null: false
    t.string "avatar_style", default: "notionists-neutral", null: false
    t.string "avatar_seed"
    t.integer "avatar_tone"
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true, where: "(email IS NOT NULL)"
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.index ["archived_at"], name: "index_users_on_archived_at"
    t.index ["archived_ordinal"], name: "index_users_on_archived_ordinal", unique: true, where: "(archived_ordinal IS NOT NULL)"
    t.index ["preferred_currency_code"], name: "index_users_on_preferred_currency_code"
    t.check_constraint "avatar_tone IS NULL OR avatar_tone >= 1 AND avatar_tone <= 16", name: "users_avatar_tone_range"
    t.check_constraint "length(btrim(name::text)) > 0", name: "users_name_present"
  end

  add_foreign_key "activity_events", "groups"
  add_foreign_key "activity_events", "users", column: "actor_id"
  add_foreign_key "exchange_rates", "currencies", column: "base_currency_code", primary_key: "code"
  add_foreign_key "exchange_rates", "currencies", column: "quote_currency_code", primary_key: "code"
  add_foreign_key "expense_participants", "expenses"
  add_foreign_key "expense_participants", "users"
  add_foreign_key "expense_payers", "expenses"
  add_foreign_key "expense_payers", "users"
  add_foreign_key "expense_splits", "expenses"
  add_foreign_key "expense_splits", "users"
  add_foreign_key "expenses", "categories"
  add_foreign_key "expenses", "currencies", column: "base_currency_code", primary_key: "code"
  add_foreign_key "expenses", "currencies", column: "currency_code", primary_key: "code"
  add_foreign_key "expenses", "groups"
  add_foreign_key "expenses", "users", column: "created_by_id"
  add_foreign_key "expenses", "users", column: "owner_id"
  add_foreign_key "expenses", "users", column: "rate_locked_by_id"
  add_foreign_key "expenses", "users", column: "voided_by_id"
  add_foreign_key "friendships", "users", column: "addressee_id"
  add_foreign_key "friendships", "users", column: "requester_id"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "groups", "currencies", column: "base_currency_code", primary_key: "code"
  add_foreign_key "groups", "users", column: "created_by_id"
  add_foreign_key "invitations", "groups"
  add_foreign_key "invitations", "users", column: "created_by_id"
  add_foreign_key "notifications", "groups"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "recovery_codes", "users"
  add_foreign_key "revisions", "users", column: "actor_id"
  add_foreign_key "settlements", "currencies", column: "base_currency_code", primary_key: "code"
  add_foreign_key "settlements", "currencies", column: "currency_code", primary_key: "code"
  add_foreign_key "settlements", "currencies", column: "settles_currency_code", primary_key: "code"
  add_foreign_key "settlements", "groups"
  add_foreign_key "settlements", "users", column: "created_by_id"
  add_foreign_key "settlements", "users", column: "payer_id"
  add_foreign_key "settlements", "users", column: "recipient_id"
  add_foreign_key "settlements", "users", column: "voided_by_id"
  add_foreign_key "users", "currencies", column: "preferred_currency_code", primary_key: "code"
end
