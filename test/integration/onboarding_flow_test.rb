require "test_helper"

# M1 驗收旅程:註冊 → 建團隊 → 邀成員 → 切換團隊
class OnboardingFlowTest < ActionDispatch::IntegrationTest
  test "註冊到邀請成員的完整流程" do
    # 註冊
    post registration_path, params: { user: {
      email_address: "founder@example.com", password: "password123", password_confirmation: "password123"
    } }
    assert_redirected_to new_team_path

    # 建立團隊
    post teams_path, params: { team: { name: "創業團隊", slug: "startup" } }
    assert_redirected_to team_root_path(team_slug: "startup")
    follow_redirect!
    assert_response :success

    # 邀請已註冊的 carol
    post settings_memberships_path(team_slug: "startup"), params: { email_address: "carol@example.com" }
    team = Team.find_by!(slug: "startup")
    assert team.users.exists?(email_address: "carol@example.com")

    # carol 登入後可以進入該團隊
    delete session_path
    sign_in_as users(:carol)
    get team_root_path(team_slug: "startup")
    assert_response :success
  end

  test "成員在多個團隊間切換" do
    sign_in_as users(:bob)

    get teams_path
    assert_response :success

    get team_root_path(team_slug: "acme")
    assert_response :success

    get team_root_path(team_slug: "globex")
    assert_response :success
  end
end
