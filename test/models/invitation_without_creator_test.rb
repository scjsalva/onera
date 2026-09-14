# frozen_string_literal: true

require "test_helper"

# A deployment starts with nobody in it. Accounts are invite-only and an
# invitation used to need a member to have created it, so the only way in was a
# shell on the server. A link with no sender is how the first person gets in.
class InvitationWithoutCreatorTest < ActiveSupport::TestCase
  test "an invitation can exist with nobody to have sent it" do
    invitation = Invitation.create!(created_by: nil, group: nil)

    assert invitation.persisted?
    assert invitation.usable?
    assert_nil invitation.referrer_name
    assert_match %r{/join/#{invitation.token}\z}, invitation.share_url("https://example.com")
  end

  test "the join page reads sensibly with no sender to name" do
    invitation = Invitation.create!(created_by: nil, group: nil)
    assert_nil invitation.referrer_name

    group = create_group(name: "Baguio", members: [ create_user(name: "A", username: "aaa") ])
    with_group = Invitation.create!(created_by: nil, group:)
    assert_nil with_group.referrer_name
    assert_equal group, with_group.group
  end

  test "a sender is still recorded when there is one" do
    john = create_user(name: "John Salva", username: "invjohn")
    invitation = Invitation.for(group: nil, creator: john)

    assert_equal "John Salva", invitation.referrer_name
  end

  test "revoking the senderless links leaves a member's own alone" do
    john = create_user(name: "John", username: "invjohn2")
    mine = Invitation.for(group: nil, creator: john)
    open = Invitation.create!(created_by: nil, group: nil)

    Invitation.live.where(created_by: nil).update_all(revoked_at: Time.current)

    assert open.reload.revoked?
    refute mine.reload.revoked?
  end
end
