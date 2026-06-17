require "test_helper"

class CustomersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:alice) }

  test "列表與搜尋" do
    get customers_path(team_slug: "acme")
    assert_response :success
    assert_select "td", text: /tom@example.com/

    get customers_path(team_slug: "acme", q: "退訂")
    assert_response :success
    assert_select "td", text: /unsub@example.com/
    assert_select "td", { text: /tom@example.com/, count: 0 }
  end

  test "客戶詳情顯示訂單與統計" do
    get customer_path(customers(:acme_tom), team_slug: "acme")
    assert_response :success
    assert_select "td", text: /ORD-1/
  end

  test "新增客戶" do
    assert_difference "teams(:acme).customers.count", 1 do
      post customers_path(team_slug: "acme"), params: { customer: { email: "NEW@example.com", name: "新客" } }
    end

    customer = teams(:acme).customers.find_by(email: "new@example.com")
    assert_redirected_to customer_path(customer, team_slug: "acme")
  end

  test "email 重複時新增失敗" do
    assert_no_difference "Customer.count" do
      post customers_path(team_slug: "acme"), params: { customer: { email: "tom@example.com" } }
    end
    assert_response :unprocessable_entity
  end

  test "更新與刪除" do
    patch customer_path(customers(:acme_tom), team_slug: "acme"), params: { customer: { name: "改名" } }
    assert_equal "改名", customers(:acme_tom).reload.name

    assert_difference "Customer.count", -1 do
      delete customer_path(customers(:acme_tom), team_slug: "acme")
    end
  end

  test "匯出 CSV(套用搜尋條件)" do
    get customers_path(team_slug: "acme", format: :csv)
    assert_response :success
    assert_match(/tom@example.com/, response.body)
    assert_match(/VIP/, response.body)
    assert_match(/unsub@example.com/, response.body)

    get customers_path(team_slug: "acme", format: :csv, q: "退訂")
    assert_no_match(/tom@example.com/, response.body)
    assert_match(/unsub@example.com/, response.body)
  end

  test "拿不到別的團隊的客戶(404)" do
    get customer_path(customers(:globex_tom), team_slug: "acme")
    assert_response :not_found
  end
end
