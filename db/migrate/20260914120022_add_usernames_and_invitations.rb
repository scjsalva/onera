# People sign in with a username. Email becomes optional again - it is asked
# for after the first sign-in and, once given, works as an alternative login.
#
# Accounts are no longer created on someone else's behalf: an existing member
# shares an invite link and the new person signs themselves up.
class AddUsernamesAndInvitations < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :username, :string
    add_column :users, :email_prompted_at, :datetime

    backfill_usernames

    change_column_null :users, :username, false
    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"

    # Email is optional again, so the unique index has to ignore the absent.
    change_column_null :users, :email, true
    execute "UPDATE users SET email = NULL WHERE email = ''"
    remove_index :users, name: "index_users_on_lower_email"
    add_index :users, "lower(email)", unique: true, where: "email IS NOT NULL",
              name: "index_users_on_lower_email"

    create_table :invitations do |t|
      t.string :token, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :group, foreign_key: true
      t.datetime :revoked_at
      t.datetime :expires_at
      t.integer :accepted_count, null: false, default: 0
      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, %i[created_by_id revoked_at]
  end

  def down
    drop_table :invitations
    remove_index :users, name: "index_users_on_lower_username"
    remove_column :users, :username
    remove_column :users, :email_prompted_at
  end

  private

  # Seeded accounts predate usernames; derive one from the name so nobody is
  # locked out by the NOT NULL that follows.
  def backfill_usernames
    known = {
      "john@onera.test" => "scjsalva",
      "christian@onera.test" => "cnasayao",
      "lydia@onera.test" => "ljvalencia",
      "kristayn@onera.test" => "kaflores",
      "eilon@onera.test" => "egblance",
      "andrew@onera.test" => "aegonia"
    }

    taken = Set.new
    select_all("SELECT id, name, email FROM users ORDER BY id").each do |row|
      candidate = known[row["email"]] || derive(row["name"], row["id"])
      candidate = "#{candidate}#{row['id']}" while taken.include?(candidate)
      taken << candidate
      execute ActiveRecord::Base.sanitize_sql([ "UPDATE users SET username = ? WHERE id = ?", candidate, row["id"] ])
    end
  end

  def derive(name, id)
    parts = name.to_s.downcase.gsub(/[^a-z ]/, "").split
    return "person#{id}" if parts.empty?

    "#{parts.first[0]}#{parts.last}"[0, 30]
  end
end
