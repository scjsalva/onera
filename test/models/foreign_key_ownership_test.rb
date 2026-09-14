# frozen_string_literal: true

require "test_helper"

# A foreign key with nobody owning it is a delete waiting to fail at the
# database. That has happened twice - invitations pointing at a group, then
# invitations pointing at a user - so this walks every one of them instead of
# waiting for the third.
class ForeignKeyOwnershipTest < ActiveSupport::TestCase
  # Currencies are reference data. They are never deleted, and giving Currency
  # a has_many for every column that names one would be noise.
  IGNORED_PARENTS = %w[currencies].freeze

  test "every foreign key has an owning association that says what happens on delete" do
    Rails.application.eager_load!
    models = ApplicationRecord.descendants.reject(&:abstract_class?).index_by(&:table_name)
    conn = ActiveRecord::Base.connection

    problems = conn.tables.flat_map do |table|
      conn.foreign_keys(table).filter_map do |fk|
        next if IGNORED_PARENTS.include?(fk.to_table)

        parent = models[fk.to_table]
        next if parent.nil? || models[table].nil?

        association = owning_association(parent, table, fk.column)
        next "#{parent.name} owns nothing for #{table}.#{fk.column}" if association.nil?

        next if association.options[:dependent] || association.options[:through]

        "#{parent.name}##{association.name} has no dependent: rule for #{table}.#{fk.column}"
      end
    end

    assert_empty problems, "unowned foreign keys:\n  #{problems.join("\n  ")}"
  end

  test "a person carrying money cannot be destroyed, and says so" do
    john = create_user(name: "John", username: "johnfk")
    alice = create_user(name: "Alice", username: "alicefk")
    group = create_group(name: "Trip", members: [ john, alice ], creator: john)
    add_expense(group:, actor: john, amount: "1000",
                payers: [ { user_id: john.id, amount: "1000" } ],
                participants: [ { user_id: john.id }, { user_id: alice.id } ])

    refute john.destroy, "a person with expenses was destroyed"
    assert john.errors.full_messages.any?, "the refusal came with no explanation"
    assert User.exists?(john.id)
  end

  test "a person carrying nothing is destroyed cleanly" do
    nobody = create_user(name: "Nobody", username: "nobodyfk")
    Invitation.create!(created_by: nobody, token: SecureRandom.hex(16))

    assert_difference "User.count", -1 do
      assert nobody.destroy, "a person with no money could not be destroyed"
    end
  end

  private

  def owning_association(parent, table, column)
    parent.reflect_on_all_associations.find do |association|
      next false unless association.macro.in?(%i[has_many has_one])

      association.klass.table_name == table && association.foreign_key.to_s == column
    rescue StandardError
      false
    end
  end
end
