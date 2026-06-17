require "test_helper"

class AudiencesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:alice) }

  test "列表顯示名稱、條件摘要與預估人數" do
    get audiences_path(team_slug: "acme")
    assert_response :success
    assert_select "td", text: /擁有標籤「VIP」/
    assert_select "td", text: /1 人/
  end

  test "用條件列建立分群,存成扁平 conditions" do
    assert_difference "teams(:acme).audiences.count", 1 do
      post audiences_path(team_slug: "acme"), params: {
        audience: {
          name: "高消費 VIP",
          rows: [
            { key: "tag", value: "VIP" },
            { key: "min_total_spent", value: "1000" },
            { key: "ordered_after", value: "2026-01-01" },
            { key: "min_orders_count", value: "" }
          ]
        }
      }
    end

    audience = teams(:acme).audiences.find_by(name: "高消費 VIP")
    assert_equal({ "tags" => [ "VIP" ], "min_total_spent" => "1000", "ordered_after" => "2026-01-01" },
                 audience.conditions)
  end

  test "沒有名稱建立失敗" do
    assert_no_difference "Audience.count" do
      post audiences_path(team_slug: "acme"), params: { audience: { name: "", rows: [] } }
    end
    assert_response :unprocessable_entity
  end

  test "不認得的條件鍵會被忽略" do
    post audiences_path(team_slug: "acme"), params: {
      audience: { name: "怪條件", rows: [ { key: "hacked_key", value: "x" } ] }
    }

    assert_equal({}, teams(:acme).audiences.find_by(name: "怪條件").conditions)
  end

  test "預覽人數" do
    post preview_audiences_path(team_slug: "acme"), params: {
      audience: { rows: [ { key: "tag", value: "VIP" } ] }
    }

    assert_response :success
    assert_match(/符合 1 位客戶/, response.body)
  end

  test "更新分群會整批換掉條件" do
    patch audience_path(audiences(:acme_vips), team_slug: "acme"), params: {
      audience: { name: "改版", rows: [ { key: "min_orders_count", value: "2" } ] }
    }

    audience = audiences(:acme_vips).reload
    assert_equal "改版", audience.name
    assert_equal({ "min_orders_count" => "2" }, audience.conditions)
  end

  test "刪除分群" do
    assert_difference "Audience.count", -1 do
      delete audience_path(audiences(:acme_all), team_slug: "acme")
    end
  end

  test "被活動使用中的分群不能刪" do
    assert_no_difference "Audience.count" do
      delete audience_path(audiences(:acme_vips), team_slug: "acme")
    end

    follow_redirect!
    assert_select "div", /無法刪除/
  end

  test "看不到別的團隊的分群(404)" do
    audience = teams(:globex).audiences.create!(name: "G", conditions: {})
    get edit_audience_path(audience, team_slug: "acme")
    assert_response :not_found
  end
end
