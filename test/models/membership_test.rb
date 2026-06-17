require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "同一個人不能重複加入同一個團隊" do
    duplicate = Membership.new(user: users(:alice), team: teams(:acme), role: :member)
    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  test "同一個人可以加入不同團隊" do
    membership = Membership.new(user: users(:carol), team: teams(:acme), role: :member)
    assert membership.valid?
  end

  test "role 只接受 owner / member" do
    membership = Membership.new(user: users(:carol), team: teams(:acme), role: "boss")
    assert_not membership.valid?
    assert membership.errors[:role].any?
  end
end
