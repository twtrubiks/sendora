require "test_helper"

class Settings::TeamsControllerTest < ActionDispatch::IntegrationTest
  test "成員可以看到團隊設定頁" do
    sign_in_as users(:bob)
    get settings_team_path(team_slug: "acme")
    assert_response :success
  end

  test "成員可以改團隊名稱" do
    sign_in_as users(:bob)
    patch settings_team_path(team_slug: "acme"), params: { team: { name: "Acme 新名字" } }
    assert_redirected_to settings_team_path(team_slug: "acme")
    assert_equal "Acme 新名字", teams(:acme).reload.name
  end

  test "改名只會改 name,不會動到 slug" do
    sign_in_as users(:alice)
    patch settings_team_path(team_slug: "acme"), params: { team: { name: "改名", slug: "hacked" } }
    assert_equal "acme", teams(:acme).reload.slug
  end

  test "一般成員不能刪除團隊" do
    sign_in_as users(:bob)

    assert_no_difference "Team.count" do
      delete settings_team_path(team_slug: "acme"), params: { confirm_slug: "acme" }
    end

    assert_redirected_to team_root_path(team_slug: "acme")
  end

  test "擁有者刪除團隊要輸入正確的 slug 確認" do
    sign_in_as users(:alice)

    assert_no_difference "Team.count" do
      delete settings_team_path(team_slug: "acme"), params: { confirm_slug: "typo" }
    end

    assert_redirected_to settings_team_path(team_slug: "acme")
  end

  test "擁有者輸入正確 slug 即可刪除團隊" do
    sign_in_as users(:alice)

    assert_difference "Team.count", -1 do
      delete settings_team_path(team_slug: "acme"), params: { confirm_slug: "acme" }
    end

    assert_redirected_to teams_path
    assert_nil Team.find_by(slug: "acme")
  end
end
