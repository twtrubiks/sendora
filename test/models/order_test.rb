require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "同團隊訂單編號不可重複" do
    order = Order.new(team: teams(:acme), customer: customers(:acme_tom), number: "ORD-1",
                      amount: 100, ordered_at: Time.current)
    assert_not order.valid?
    assert order.errors[:number].any?
  end

  test "不同團隊可以有相同訂單編號" do
    order = Order.new(team: teams(:globex), customer: customers(:globex_tom), number: "ORD-1",
                      amount: 100, ordered_at: Time.current)
    assert order.valid?
  end

  test "金額不可為負數" do
    order = Order.new(team: teams(:acme), customer: customers(:acme_tom), number: "ORD-X",
                      amount: -1, ordered_at: Time.current)
    assert_not order.valid?
    assert order.errors[:amount].any?
  end
end
