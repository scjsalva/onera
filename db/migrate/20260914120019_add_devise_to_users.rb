# Authentication arrives. The financial domain is untouched: a User is still
# the same row, still referenced by every expense and settlement. What changes
# is only how Current.user gets established.
class AddDeviseToUsers < ActiveRecord::Migration[8.0]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    change_table :users, bulk: true do |t|
      t.string   :encrypted_password, null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.datetime :last_sign_in_at
    end

    # Email was optional profile information; it is now the sign-in identity,
    # so anyone who predates authentication needs one before it can be unique.
    backfill_emails

    change_column_null :users, :email, false
    remove_index :users, name: "index_users_on_lower_email"
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
    add_index :users, :reset_password_token, unique: true
  end

  def down
    remove_index :users, :reset_password_token
    remove_index :users, name: "index_users_on_lower_email"
    add_index :users, "lower(email)", unique: true, where: "email IS NOT NULL",
              name: "index_users_on_lower_email"
    change_column_null :users, :email, true

    change_table :users, bulk: true do |t|
      t.remove :encrypted_password, :reset_password_token, :reset_password_sent_at,
               :remember_created_at, :last_sign_in_at
    end
  end

  private

  def backfill_emails
    taken = MigrationUser.where.not(email: [ nil, "" ]).pluck(:email).map(&:downcase).to_set

    MigrationUser.where(email: [ nil, "" ]).order(:id).each do |user|
      base = user.name.to_s.parameterize.presence || "person-#{user.id}"
      candidate = "#{base}@onera.test"
      candidate = "#{base}-#{user.id}@onera.test" if taken.include?(candidate)
      taken << candidate
      user.update_columns(email: candidate)
    end
  end
end
