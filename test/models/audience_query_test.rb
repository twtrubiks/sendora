require "test_helper"

# 測試資料(fixtures):
#   acme_tom:   標籤 VIP;訂單 ORD-1(500,2026-05-10)、ORD-2(1280.5,2026-06-01)
#   acme_unsub: 無標籤、無訂單
class AudienceQueryTest < ActiveSupport::TestCase
  setup { @team = teams(:acme) }

  test "沒有條件時回傳全部客戶" do
    assert_equal @team.customers.count, query({}).count
  end

  test "標籤條件:必須擁有列出的每一個標籤" do
    assert_equal [ customers(:acme_tom) ], query("tags" => [ "VIP" ]).customers.to_a
    assert_empty query("tags" => [ "VIP", "新客" ]).customers
  end

  test "不存在的標籤回傳空集合" do
    assert_empty query("tags" => [ "沒這個標籤" ]).customers
  end

  test "累計消費下限與上限" do
    assert_equal [ customers(:acme_tom) ], query("min_total_spent" => "1000").customers.to_a
    assert_empty query("min_total_spent" => "5000").customers

    # 沒有訂單的客戶累計消費視為 0,符合上限條件
    assert_equal [ customers(:acme_unsub) ], query("max_total_spent" => "100").customers.to_a
  end

  test "訂單數下限" do
    assert_equal [ customers(:acme_tom) ], query("min_orders_count" => "2").customers.to_a
    assert_empty query("min_orders_count" => "3").customers
  end

  test "最近購買日:之後與早於" do
    assert_equal [ customers(:acme_tom) ], query("ordered_after" => "2026-06-01").customers.to_a
    assert_empty query("ordered_after" => "2026-06-02").customers

    # 從未購買的客戶沒有最近購買日,不符合「早於」
    assert_equal [ customers(:acme_tom) ], query("ordered_before" => "2026-07-01").customers.to_a
    assert_empty query("ordered_before" => "2026-05-01").customers
  end

  test "建立日期區間" do
    assert_equal @team.customers.count, query("created_after" => Date.yesterday.to_s).count
    assert_equal 0, query("created_before" => Date.yesterday.to_s).count
  end

  test "條件之間是 AND" do
    result = query("tags" => [ "VIP" ], "min_total_spent" => "1000", "min_orders_count" => "2")
    assert_equal [ customers(:acme_tom) ], result.customers.to_a

    assert_empty query("tags" => [ "VIP" ], "min_total_spent" => "99999").customers
  end

  test "無效的值會被忽略" do
    assert_equal @team.customers.count, query("min_total_spent" => "abc", "ordered_after" => "not-a-date").count
  end

  test "只查得到自己團隊的客戶" do
    globex_query = AudienceQuery.new(teams(:globex), { "tags" => [ "VIP" ] })
    assert_empty globex_query.customers

    assert_not_includes query({}).customers, customers(:globex_tom)
  end

  private
    def query(conditions)
      AudienceQuery.new(@team, conditions)
    end
end
