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

  test "刪除客戶保留已寄出與失敗的發送紀錄(本月額度不退),斷開關聯並清掉錯誤訊息;未寄的刪掉" do
    team = teams(:acme)
    tom = customers(:acme_tom)
    campaign = campaigns(:acme_draft)
    sent = campaign.deliveries.create!(team: team, customer: tom, status: :sent)
    other = team.campaigns.create!(audience: audiences(:acme_all), name: "另一檔", subject: "s", body: "b")
    failed = other.deliveries.create!(team: team, customer: tom, status: :failed, error_message: "550 5.1.1 <tom@example.com>")
    third = team.campaigns.create!(audience: audiences(:acme_all), name: "第三檔", subject: "s", body: "b")
    third.deliveries.create!(team: team, customer: tom, status: :pending)

    assert_difference -> { team.monthly_sent_count }, -1 do   # 只少了沒寄出的那筆
      tom.destroy!
    end

    assert_nil sent.reload.customer_id
    assert sent.sent?
    assert_nil failed.reload.customer_id
    assert_nil failed.error_message
    assert_equal 0, third.deliveries.count
  end
end
