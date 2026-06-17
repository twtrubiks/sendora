require "test_helper"

class UnsubscribesControllerTest < ActionDispatch::IntegrationTest
  setup { @token = customers(:acme_tom).generate_token_for(:unsubscribe) }

  test "退訂頁不需登入,顯示確認鈕" do
    get unsubscribe_path(@token)
    assert_response :success
    assert_select "h1", "退訂行銷信件"
    assert_match "tom@example.com", response.body
  end

  test "確認退訂後寫入 unsubscribed_at,重複退訂不報錯" do
    post unsubscribe_path(@token)
    assert_response :success

    first_time = customers(:acme_tom).reload.unsubscribed_at
    assert first_time.present?

    travel 1.hour do
      post unsubscribe_path(@token)
      assert_equal first_time, customers(:acme_tom).reload.unsubscribed_at
    end
  end

  test "無效 token 回 404" do
    get unsubscribe_path("bogus-token")
    assert_response :not_found

    post unsubscribe_path("bogus-token")
    assert_response :not_found
  end

  test "token 過期後失效" do
    travel 31.days do
      get unsubscribe_path(@token)
      assert_response :not_found
    end
  end
end
