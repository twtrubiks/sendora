require "test_helper"

# M4 驗收旅程:建活動 → 確認發送 → 背景寄送 → 成效;退訂後不再收信
class CampaignFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "對分群發信到看見成效" do
    sign_in_as users(:alice)

    post campaigns_path(team_slug: "acme"), params: { campaign: {
      name: "驗收活動", audience_id: audiences(:acme_all).id,
      subject: "{{name}} 你好", body: "內文 {{name}}"
    } }
    campaign = teams(:acme).campaigns.find_by(name: "驗收活動")

    # acme_all 有 2 位客戶,但 acme_unsub 已退訂 → 只寄 1 封
    assert_emails 1 do
      perform_enqueued_jobs do
        post deliver_campaign_path(campaign, team_slug: "acme")
      end
    end

    campaign.reload
    assert campaign.sent?
    assert_equal 1, campaign.deliveries.sent.count

    get campaign_path(campaign, team_slug: "acme")
    assert_response :success
  end

  test "SMTP 故障中斷後接續寄送:已寄出的不重寄,只寄剩下的" do
    teams(:acme).customers.create!(email: "amy@example.com", name: "Amy")
    teams(:acme).customers.create!(email: "ben@example.com", name: "Ben")
    sign_in_as users(:alice)
    post campaigns_path(team_slug: "acme"), params: { campaign: {
      name: "中斷活動", audience_id: audiences(:acme_all).id, subject: "s", body: "b"
    } }
    campaign = teams(:acme).campaigns.find_by(name: "中斷活動")

    # 寄出第 1 封後 SMTP 認證開始失敗 → 中止發送
    sent = 0
    original = CampaignMailer.method(:marketing)
    CampaignMailer.singleton_class.define_method(:marketing) do |delivery|
      raise Net::SMTPAuthenticationError.new("535 5.7.8 Authentication failed") if sent == 1

      sent += 1
      original.call(delivery)
    end
    begin
      assert_emails 1 do
        perform_enqueued_jobs { post deliver_campaign_path(campaign, team_slug: "acme") }
      end
    ensure
      CampaignMailer.singleton_class.remove_method(:marketing)
    end

    assert campaign.reload.failed?
    assert_equal 1, campaign.deliveries.sent.count
    assert_equal 2, campaign.deliveries.pending.count

    # 修好 SMTP 設定後接續 → 只寄剩下 2 位
    assert_emails 2 do
      perform_enqueued_jobs { post resume_campaign_path(campaign, team_slug: "acme") }
    end

    campaign.reload
    assert campaign.sent?
    assert_equal 3, campaign.deliveries.sent.count
    assert_equal 3, ActionMailer::Base.deliveries.map(&:to).flatten.uniq.size, "沒有人收到兩封"
  end

  test "退訂後不再收信" do
    # tom 透過信中連結退訂
    token = customers(:acme_tom).generate_token_for(:unsubscribe)
    post unsubscribe_path(token)
    assert customers(:acme_tom).reload.unsubscribed?

    # 對全部客戶再發一檔活動 → 沒有人可寄(兩位都退訂)
    sign_in_as users(:alice)
    post campaigns_path(team_slug: "acme"), params: { campaign: {
      name: "退訂後活動", audience_id: audiences(:acme_all).id, subject: "s", body: "b"
    } }
    campaign = teams(:acme).campaigns.find_by(name: "退訂後活動")

    get confirm_campaign_path(campaign, team_slug: "acme")
    assert_select "span", /沒有可寄送的客戶/
  end
end
