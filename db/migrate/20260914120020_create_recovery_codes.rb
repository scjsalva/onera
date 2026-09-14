# Password recovery without email.
#
# Each person gets a set of single-use codes they save somewhere offline. That
# keeps the app deployable with no mail service, no domain reputation and no
# deliverability problems - which for a personal app is the difference between
# recovery that works and recovery that only works in theory.
#
# Only a digest is stored. A code is shown exactly once, when it is generated;
# after that the app can tell you which ones remain unused but not what they
# say - the same reason a password is not readable back.
class CreateRecoveryCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :recovery_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false
      t.integer :position, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :recovery_codes, :code_digest, unique: true
    add_index :recovery_codes, %i[user_id position], unique: true
    add_index :recovery_codes, %i[user_id used_at]

    # Email recovery is not wired up, so its columns would only be dead weight.
    remove_column :users, :reset_password_token, :string
    remove_column :users, :reset_password_sent_at, :datetime
    add_column :users, :recovery_codes_generated_at, :datetime
  end
end
