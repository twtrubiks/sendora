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
end
