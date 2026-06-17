require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  test "未登入導向登入頁" do
    get teams_path
    assert_redirected_to new_session_path
  end

  test "沒有團隊時導向建立團隊" do
    sign_in_as users(:carol)
    get teams_path
    assert_redirected_to new_team_path
  end

  test "列出自己的團隊" do
    sign_in_as users(:bob)
    get teams_path
    assert_response :success
    assert_select "a", text: /Acme 商店/
    assert_select "a", text: /Globex/
  end

  test "建立團隊後成為擁有者並導向儀表板" do
    sign_in_as users(:carol)

    assert_difference [ "Team.count", "Membership.count" ], 1 do
      post teams_path, params: { team: { name: "Carol 的店", slug: "carol-shop" } }
    end

    assert_redirected_to team_root_path(team_slug: "carol-shop")
    membership = users(:carol).memberships.joins(:team).find_by(teams: { slug: "carol-shop" })
    assert membership.owner?
  end

  test "slug 重複時建立失敗" do
    sign_in_as users(:carol)

    assert_no_difference "Team.count" do
      post teams_path, params: { team: { name: "撞名", slug: "acme" } }
    end

    assert_response :unprocessable_entity
  end
end
