# Who can see whom.
#
# Onera is not a social network, so this is the smallest thing that answers
# one question: may these two people put each other on an expense outside a
# group? A shared group answers it for that group only - outside it, they are
# strangers again unless they have actually added each other.
class CreateFriendships < ActiveRecord::Migration[8.0]
  def change
    create_table :friendships do |t|
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :addressee, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.datetime :responded_at
      t.timestamps
    end

    add_index :friendships, %i[requester_id addressee_id], unique: true
    add_index :friendships, %i[addressee_id status]
    add_check_constraint :friendships, "requester_id <> addressee_id", name: "friendships_distinct_people"
    add_check_constraint :friendships, "status IN ('pending','accepted')", name: "friendships_status_valid"
  end
end
