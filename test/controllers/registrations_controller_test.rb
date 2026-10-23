require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  VALID_USER = { email_address: "newbie@example.com", password: "password123", password_confirmation: "password123" }.freeze

  test "註冊頁" do
    get new_registration_path
    assert_response :success
    assert_no_match "邀請碼", response.body
  end

  test "註冊成功後自動登入並導向建立團隊" do
    assert_difference "User.count", 1 do
      post registration_path, params: { user: VALID_USER }
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

  test "設了邀請碼:註冊頁多邀請碼欄位,憑正確的碼才能註冊" do
    with_signup_code("secret-code") do
      get new_registration_path
      assert_response :success
      assert_match "邀請碼", response.body

      assert_difference "User.count", 1 do
        post registration_path, params: { user: VALID_USER, signup_code: "secret-code" }
      end
      assert_redirected_to new_team_path
    end
  end

  test "設了邀請碼:碼錯誤或沒帶都擋下,表單保留已填的 email" do
    with_signup_code("secret-code") do
      [ { signup_code: "wrong" }, {} ].each do |extra|
        assert_no_difference "User.count" do
          post registration_path, params: { user: VALID_USER }.merge(extra)
        end

        assert_response :unprocessable_entity
        assert_match "邀請碼不正確", response.body
        assert_match "newbie@example.com", response.body
        assert cookies[:session_id].blank?
      end
    end
  end

  test "production 沒設邀請碼:關閉註冊,註冊頁與送出都導回登入頁,登入頁不顯示註冊連結" do
    with_signup_closed_without_code do
      get new_registration_path
      assert_redirected_to new_session_path
      assert_equal "目前不開放註冊,請聯絡系統管理者", flash[:alert]

      assert_no_difference "User.count" do
        post registration_path, params: { user: VALID_USER }
      end
      assert_redirected_to new_session_path

      get new_session_path
      assert_select "a[href=?]", new_registration_path, count: 0
    end
  end

  test "production 設了邀請碼:照常開放,登入頁顯示註冊連結" do
    with_signup_closed_without_code do
      with_signup_code("secret-code") do
        get new_session_path
        assert_select "a[href=?]", new_registration_path, count: 1

        get new_registration_path
        assert_response :success
      end
    end
  end

  private
    def with_signup_code(code)
      original = ENV["SIGNUP_CODE"]
      ENV["SIGNUP_CODE"] = code
      yield
    ensure
      ENV["SIGNUP_CODE"] = original
    end

    # 模擬 production:沒設邀請碼就關閉註冊
    def with_signup_closed_without_code
      original = Signup.closed_without_code
      Signup.closed_without_code = true
      yield
    ensure
      Signup.closed_without_code = original
    end
end
