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

  test "新增與編輯表單頁" do
    get new_customer_path(team_slug: "acme")
    assert_response :success
    assert_select "input[name='customer[email]']"

    get edit_customer_path(customers(:acme_tom), team_slug: "acme")
    assert_response :success
    assert_select "input[name='customer[email]'][value='tom@example.com']"
  end

  test "email 重複時新增失敗,欄位下方顯示原因" do
    assert_no_difference "Customer.count" do
      post customers_path(team_slug: "acme"), params: { customer: { email: "tom@example.com" } }
    end
    assert_response :unprocessable_entity
    assert_select "p.text-red-600", "已被使用"
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

  test "匯出 CSV 的欄位內容:多個標籤以 | 串接,退訂 / 退信 / 建立日期" do
    customers(:acme_tom).tags << tags(:acme_new)
    customers(:acme_tom).update!(phone: "0911222333", bounced_at: Time.zone.parse("2026-06-02 09:00"))

    get customers_path(team_slug: "acme", format: :csv)

    rows = CSV.parse(response.body, headers: true).to_h { [ it["email"], it.to_h ] }
    assert_equal %w[ email name phone tags unsubscribed_at bounced_at created_at ], rows.values.first.keys
    tom = rows.fetch("tom@example.com")
    assert_equal [ "Tom 陳", "0911222333", "VIP|新客", nil, "2026-06-02" ],
                 tom.values_at("name", "phone", "tags", "unsubscribed_at", "bounced_at")
    assert_equal customers(:acme_tom).created_at.strftime("%Y-%m-%d"), tom["created_at"]
    assert_equal "2026-05-01", rows.fetch("unsub@example.com")["unsubscribed_at"]
  end

  test "拿不到別的團隊的客戶(404)" do
    get customer_path(customers(:globex_tom), team_slug: "acme")
    assert_response :not_found
  end
end
