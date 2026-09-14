# frozen_string_literal: true

require "test_helper"

class FriendshipTest < ActiveSupport::TestCase
  setup do
    @a = create_user(name: "Ann", username: "annf")
    @b = create_user(name: "Ben", username: "benf")
    @c = create_user(name: "Cal", username: "calf")
  end

  test "a request starts pending and connects nobody yet" do
    Friendship.request(from: @a, to: @b)

    refute @a.friends_with?(@b)
    assert @a.friend_request_pending_with?(@b)
    assert_empty @a.friends
  end

  test "accepting connects both directions" do
    Friendship.request(from: @a, to: @b).accept!

    assert @a.friends_with?(@b)
    assert @b.friends_with?(@a)
    assert_includes @a.friends, @b
    assert_includes @b.friends, @a
  end

  test "asking someone who already asked you is the same as accepting" do
    Friendship.request(from: @a, to: @b)
    Friendship.request(from: @b, to: @a)

    assert @a.friends_with?(@b)
    assert_equal 1, Friendship.count
  end

  test "asking twice does not pile up requests" do
    first = Friendship.request(from: @a, to: @b)
    second = Friendship.request(from: @a, to: @b)

    assert_equal first, second
    assert_equal 1, Friendship.count
  end

  test "you cannot add yourself" do
    friendship = Friendship.new(requester: @a, addressee: @a)

    refute friendship.valid?
  end

  test "friendship is not transitive" do
    Friendship.request(from: @a, to: @b).accept!
    Friendship.request(from: @a, to: @c).accept!

    refute @b.friends_with?(@c)
    refute_includes @b.friends, @c
  end

  test "removing a connection leaves no trace of it" do
    Friendship.request(from: @a, to: @b).accept!
    Friendship.between(@a, @b).destroy!

    refute @a.reload.friends_with?(@b)
    assert_empty @a.friends
  end

  test "a closed account drops out of your people" do
    Friendship.request(from: @a, to: @b).accept!
    UserAnonymizer.call(user: @b)

    refute_includes @a.friends, @b.reload
  end
end
