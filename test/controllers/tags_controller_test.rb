require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:alice) }

  test "列表顯示標籤與客戶數" do
    get tags_path(team_slug: "acme")
    assert_response :success
    assert_select "span", text: "VIP"
  end

  test "建立標籤" do
    assert_difference "teams(:acme).tags.count", 1 do
      post tags_path(team_slug: "acme"), params: { tag: { name: "熟客" } }
    end
  end

  test "同名標籤建立失敗並顯示原因" do
    assert_no_difference "Tag.count" do
      post tags_path(team_slug: "acme"), params: { tag: { name: "VIP" } }
    end

    follow_redirect!
    assert_select "div", /已被使用/
  end

  test "改名與刪除" do
    patch tag_path(tags(:acme_vip), team_slug: "acme"), params: { tag: { name: "超級VIP" } }
    assert_equal "超級VIP", tags(:acme_vip).reload.name

    assert_difference "Tag.count", -1 do
      delete tag_path(tags(:acme_vip), team_slug: "acme")
    end
  end

  test "動不到別的團隊的標籤(404)" do
    get edit_tag_path(tags(:globex_vip), team_slug: "acme")
    assert_response :not_found
  end
end
