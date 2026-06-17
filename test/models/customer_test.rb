require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "同團隊 email 不可重複" do
    customer = teams(:acme).customers.new(email: "TOM@example.com")
    assert_not customer.valid?
    assert customer.errors[:email].any?
  end

  test "不同團隊可以有相同 email" do
    assert customers(:acme_tom).valid?
    assert customers(:globex_tom).valid?
  end

  test "email 格式不正確時無效" do
    customer = teams(:acme).customers.new(email: "not-an-email")
    assert_not customer.valid?
  end

  test "search 同時比對 email 與姓名,大小寫不拘" do
    results = teams(:acme).customers.search("TOM")
    assert_includes results, customers(:acme_tom)
    assert_not_includes results, customers(:acme_unsub)

    assert_includes teams(:acme).customers.search("退訂"), customers(:acme_unsub)
    assert_equal teams(:acme).customers.count, teams(:acme).customers.search("").count
  end

  test "search 會跳脫 LIKE 萬用字元" do
    assert_empty teams(:acme).customers.search("%")
  end

  test "退訂與退信狀態" do
    assert customers(:acme_unsub).unsubscribed?
    assert_not customers(:acme_tom).unsubscribed?
    assert_not customers(:acme_tom).bounced?
  end
end
