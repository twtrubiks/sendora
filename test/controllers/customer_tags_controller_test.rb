require "test_helper"

class CustomerTagsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:alice) }

  test "替客戶貼標籤" do
    assert_difference "CustomerTag.count", 1 do
      post customer_tags_path(customers(:acme_unsub), team_slug: "acme"),
           params: { tag_id: tags(:acme_vip).id }
    end
  end

  test "重複貼同一個標籤不報錯也不重複" do
    assert_no_difference "CustomerTag.count" do
      post customer_tags_path(customers(:acme_tom), team_slug: "acme"),
           params: { tag_id: tags(:acme_vip).id }
    end
    assert_response :redirect
  end

  test "撕下標籤" do
    assert_difference "CustomerTag.count", -1 do
      delete customer_tag_path(customers(:acme_tom), tags(:acme_vip), team_slug: "acme")
    end
  end

  test "貼不了別的團隊的標籤(404)" do
    post customer_tags_path(customers(:acme_tom), team_slug: "acme"),
         params: { tag_id: tags(:globex_vip).id }
    assert_response :not_found
  end
end
