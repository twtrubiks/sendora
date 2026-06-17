require "test_helper"

class Settings::MembershipsControllerTest < ActionDispatch::IntegrationTest
  test "擁有者可以看到成員列表" do
    sign_in_as users(:alice)
    get settings_memberships_path(team_slug: "acme")
    assert_response :success
    assert_select "td", text: /bob@example.com/
  end

  test "一般成員不能進成員管理頁" do
    sign_in_as users(:bob)
    get settings_memberships_path(team_slug: "acme")
    assert_redirected_to team_root_path(team_slug: "acme")
  end

  test "擁有者用 email 邀請已註冊的使用者" do
    sign_in_as users(:alice)

    assert_difference "Membership.count", 1 do
      post settings_memberships_path(team_slug: "acme"), params: { email_address: "Carol@example.com " }
    end

    membership = teams(:acme).memberships.find_by(user: users(:carol))
    assert membership.member?
  end

  test "邀請未註冊的 email 顯示提示" do
    sign_in_as users(:alice)

    assert_no_difference "Membership.count" do
      post settings_memberships_path(team_slug: "acme"), params: { email_address: "ghost@example.com" }
    end

    assert_redirected_to settings_memberships_path(team_slug: "acme")
    follow_redirect!
    assert_select "div", /找不到/
  end

  test "邀請已是成員的 email 顯示提示" do
    sign_in_as users(:alice)

    assert_no_difference "Membership.count" do
      post settings_memberships_path(team_slug: "acme"), params: { email_address: "bob@example.com" }
    end

    follow_redirect!
    assert_select "div", /已是團隊成員/
  end

  test "一般成員不能邀請" do
    sign_in_as users(:bob)

    assert_no_difference "Membership.count" do
      post settings_memberships_path(team_slug: "acme"), params: { email_address: "carol@example.com" }
    end
  end

  test "擁有者可以移除成員" do
    sign_in_as users(:alice)

    assert_difference "Membership.count", -1 do
      delete settings_membership_path(memberships(:bob_acme), team_slug: "acme")
    end
  end

  test "不能移除最後一位擁有者" do
    sign_in_as users(:alice)

    assert_no_difference "Membership.count" do
      delete settings_membership_path(memberships(:alice_acme), team_slug: "acme")
    end

    follow_redirect!
    assert_select "div", /最後一位擁有者/
  end
end
