require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "成員可以看到團隊儀表板(KPI、圖表、近期活動)" do
    sign_in_as users(:bob)
    get team_root_path(team_slug: "acme")
    assert_response :success
    assert_select "p", text: "營收"
    assert_select "p", text: "活躍客戶"
    assert_select "h2", text: "近期活動結果"
  end

  test "區間切換,非法值回落到本月" do
    sign_in_as users(:alice)

    get team_root_path(team_slug: "acme", period: "last_month")
    assert_response :success

    get team_root_path(team_slug: "acme", period: "hacked")
    assert_response :success
  end

  test "KPI 依區間計算本期與上期:本月 / 上月 / 近 30 天,非法值回落到本月" do
    travel_to Time.zone.parse("2026-07-15 12:00") do
      # fixtures 已有 ORD-1(500,5/10)、ORD-2(1280.5,6/1);fixture 客戶建立於真實的現在,不落在任何區間
      team = teams(:acme)
      tom = customers(:acme_tom)
      amy = team.customers.create!(email: "amy@example.com")   # 7/15 新客
      tom.orders.create!(team: team, number: "ORD-6B", amount: 100, ordered_at: Time.zone.parse("2026-06-20 10:00"))
      tom.orders.create!(team: team, number: "ORD-7A", amount: 300, ordered_at: Time.zone.parse("2026-07-03 10:00"))
      amy.orders.create!(team: team, number: "ORD-7B", amount: 200, ordered_at: Time.zone.parse("2026-07-10 10:00"))
      sign_in_as users(:alice)

      this_month = { "營收" => %w[ 500 1,380 ], "訂單數" => %w[ 2 2 ], "新客戶" => %w[ 1 0 ], "活躍客戶" => %w[ 2 1 ] }
      get team_root_path(team_slug: "acme")
      assert_equal this_month, kpi_cards

      get team_root_path(team_slug: "acme", period: "hacked")
      assert_equal this_month, kpi_cards

      get team_root_path(team_slug: "acme", period: "last_month")   # 6 月;上期 5 月
      assert_equal({ "營收" => %w[ 1,380 500 ], "訂單數" => %w[ 2 1 ], "新客戶" => %w[ 0 0 ], "活躍客戶" => %w[ 1 1 ] }, kpi_cards)

      get team_root_path(team_slug: "acme", period: "last_30_days")   # 6/15 起到現在;上期 5/16 ~ 6/14
      assert_equal({ "營收" => %w[ 600 1,280 ], "訂單數" => %w[ 3 1 ], "新客戶" => %w[ 1 0 ], "活躍客戶" => %w[ 2 1 ] }, kpi_cards)
    end
  end

  test "近 30 天的區間邊界:從 30 天前的 0 點起算,上期是再往前 30 天" do
    travel_to Time.zone.parse("2026-07-15 12:00") do
      tom = customers(:acme_tom)
      { "B1" => "2026-06-15 00:00", "B2" => "2026-06-14 23:59", "B3" => "2026-05-16 00:00", "B4" => "2026-05-15 23:59" }.each do |number, at|
        tom.orders.create!(team: teams(:acme), number: number, amount: 1, ordered_at: Time.zone.parse(at))
      end
      sign_in_as users(:alice)

      get team_root_path(team_slug: "acme", period: "last_30_days")

      # 本期只有 B1;上期 B2、B3 加上 fixture 的 ORD-2(6/1);B4 兩期都不算
      assert_equal %w[ 1 3 ], kpi_cards["訂單數"]
    end
  end

  test "沒有客戶資料時顯示引導式空狀態" do
    team = Team.create!(name: "空團隊", slug: "empty-team")
    team.memberships.create!(user: users(:bob), role: :owner)

    sign_in_as users(:bob)
    get team_root_path(team_slug: "empty-team")
    assert_response :success
    assert_select "p", text: "還沒有資料"
  end

  test "非成員導回首頁,訊息中性不洩漏團隊是否存在" do
    sign_in_as users(:carol)
    get team_root_path(team_slug: "acme")
    assert_redirected_to root_path
    assert_equal "找不到團隊,或你沒有存取權限", flash[:alert]
  end

  test "不存在的團隊也導回首頁,回應與非成員完全一致" do
    sign_in_as users(:bob)
    get team_root_path(team_slug: "no-such-team")
    assert_redirected_to root_path
    assert_equal "找不到團隊,或你沒有存取權限", flash[:alert]
  end

  test "未登入導向登入頁" do
    get team_root_path(team_slug: "acme")
    assert_redirected_to new_session_path
  end

  private
    # KPI 卡:{ 標籤 => [ 本期, 上期 ] }
    def kpi_cards
      css_select("div.grid-cols-2 > div").to_h do |card|
        label, current, previous = card.css("p").map { it.text.strip }
        [ label, [ current, previous.delete_prefix("上期 ") ] ]
      end
    end
end
