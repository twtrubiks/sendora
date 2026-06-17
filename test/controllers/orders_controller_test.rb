require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:alice) }

  test "替客戶新增訂單" do
    assert_difference "customers(:acme_tom).orders.count", 1 do
      post customer_orders_path(customers(:acme_tom), team_slug: "acme"),
           params: { order: { number: "ORD-NEW", amount: 350, ordered_at: "2026-06-10" } }
    end

    order = customers(:acme_tom).orders.find_by(number: "ORD-NEW")
    assert_equal teams(:acme), order.team
  end

  test "訂單編號重複顯示錯誤" do
    assert_no_difference "Order.count" do
      post customer_orders_path(customers(:acme_tom), team_slug: "acme"),
           params: { order: { number: "ORD-1", amount: 350, ordered_at: "2026-06-10" } }
    end

    follow_redirect!
    assert_select "div", /已被使用/
  end

  test "刪除訂單" do
    assert_difference "Order.count", -1 do
      delete customer_order_path(customers(:acme_tom), orders(:acme_tom_first), team_slug: "acme")
    end
  end

  test "不能對別的團隊的客戶下單(404)" do
    post customer_orders_path(customers(:globex_tom), team_slug: "acme"),
         params: { order: { number: "X", amount: 1, ordered_at: "2026-06-10" } }
    assert_response :not_found
  end
end
