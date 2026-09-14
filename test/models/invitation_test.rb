# frozen_string_literal: true

require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  setup do
    @host = create_user(name: "Host", username: "invhost")
    @group = create_group(name: "Trip", members: [ @host ], creator: @host)
  end

  test "a token is generated and is hard to guess" do
    invitation = Invitation.create!(created_by: @host)

    assert invitation.token.present?
    assert_operator invitation.token.length, :>=, 12
  end

  test "tokens are unique across invitations" do
    tokens = 20.times.map { Invitation.create!(created_by: @host).token }

    assert_equal tokens.uniq.size, tokens.size
  end

  test "tokens carry no punctuation that breaks in a url or a chat message" do
    assert_match(/\A[A-Za-z0-9]+\z/, Invitation.create!(created_by: @host).token)
  end

  test "asking twice reuses the live link rather than piling them up" do
    first = Invitation.for(group: @group, creator: @host)
    second = Invitation.for(group: @group, creator: @host)

    assert_equal first, second
  end

  test "a revoked link is replaced by the next request" do
    first = Invitation.for(group: @group, creator: @host)
    first.revoke!
    second = Invitation.for(group: @group, creator: @host)

    refute_equal first, second
    refute first.usable?
    assert second.usable?
  end

  test "an expired link stops being usable" do
    invitation = Invitation.create!(created_by: @host, expires_at: 1.minute.ago)

    refute invitation.usable?
    refute_includes Invitation.live, invitation
  end

  test "group and general invites are kept apart" do
    general = Invitation.for(group: nil, creator: @host)
    grouped = Invitation.for(group: @group, creator: @host)

    refute_equal general, grouped
  end

  test "the share url is built from whatever host it is asked for" do
    invitation = Invitation.create!(created_by: @host)

    assert_equal "https://onera.onrender.com/join/#{invitation.token}",
                 invitation.share_url("https://onera.onrender.com")
    assert_equal "http://192.168.1.5:3000/join/#{invitation.token}",
                 invitation.share_url("http://192.168.1.5:3000/")
  end
end
