require "test_helper"

class UnsubscribesControllerTest < ActionDispatch::IntegrationTest
  IOS_16_SAFARI = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 " \
                  "(KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"

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

  test "退訂連結不會過期:一年前的信也能退訂" do
    travel 1.year do
      post unsubscribe_path(@token)
      assert_response :success
      assert customers(:acme_tom).reload.unsubscribed?
    end
  end

  test "客戶 email 變更後,舊信的退訂連結失效" do
    customers(:acme_tom).update!(email: "tom.new@example.com")

    get unsubscribe_path(@token)
    assert_response :not_found
  end

  test "收件人用舊版瀏覽器也能退訂(後台頁面照樣擋舊瀏覽器)" do
    get new_session_path, headers: { "User-Agent" => IOS_16_SAFARI }
    assert_response :not_acceptable

    get unsubscribe_path(@token), headers: { "User-Agent" => IOS_16_SAFARI }
    assert_response :success

    post unsubscribe_path(@token), headers: { "User-Agent" => IOS_16_SAFARI }
    assert_response :success
    assert customers(:acme_tom).reload.unsubscribed?
  end
end
