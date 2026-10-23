require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "登入的 session cookie 帶 HttpOnly、SameSite=Lax,且是長期有效的 cookie" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    cookie = Array(response.headers["set-cookie"]).flat_map { it.split("\n") }
                                                    .find { it.start_with?("session_id=") }
    assert cookie, "沒有設定 session_id cookie"
    assert_match(/;\s*httponly/i, cookie)
    assert_match(/;\s*samesite=lax/i, cookie)

    expires = Time.httpdate(cookie[/expires=([^;]+)/i, 1])
    assert_operator expires, :>, 1.year.from_now
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
