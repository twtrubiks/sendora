require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "註冊頁" do
    get new_registration_path
    assert_response :success
  end

  test "註冊成功後自動登入並導向建立團隊" do
    assert_difference "User.count", 1 do
      post registration_path, params: { user: {
        email_address: "newbie@example.com", password: "password123", password_confirmation: "password123"
      } }
    end

    assert_redirected_to new_team_path
    assert cookies[:session_id].present?
  end

  test "密碼太短註冊失敗" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: {
        email_address: "newbie@example.com", password: "short", password_confirmation: "short"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "email 已被使用註冊失敗" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: {
        email_address: users(:alice).email_address, password: "password123", password_confirmation: "password123"
      } }
    end

    assert_response :unprocessable_entity
  end
end
