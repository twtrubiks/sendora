require "test_helper"

class CampaignSendJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @team = teams(:acme)
    @campaign = campaigns(:acme_draft)   # 分群:VIP(只有 acme_tom)
    @campaign.update!(status: :sending)
  end

  test "建立 Delivery、寄信、標記 sent" do
    assert_emails 1 do
      CampaignSendJob.perform_now(@campaign)
    end

    @campaign.reload
    assert @campaign.sent?
    assert @campaign.sent_at.present?

    delivery = @campaign.deliveries.sole
    assert delivery.sent?
    assert_equal customers(:acme_tom), delivery.customer
  end

  test "自動排除已退訂與退信的客戶" do
    @campaign.update!(audience: audiences(:acme_all))
    customers(:acme_tom).update!(bounced_at: Time.current)
    # acme_unsub 已退訂、acme_tom 退信 → 沒有可寄送對象

    assert_no_emails do
      CampaignSendJob.perform_now(@campaign)
    end

    assert_equal 0, @campaign.deliveries.count
    assert @campaign.reload.sent?
  end

  test "額度不足:標記 failed 並附原因,不建立 Delivery" do
    @team.update!(monthly_send_quota: 0)

    assert_no_emails do
      CampaignSendJob.perform_now(@campaign)
    end

    @campaign.reload
    assert @campaign.failed?
    assert_match(/超出本月發送額度/, @campaign.error_message)
    assert_equal 0, @campaign.deliveries.count
  end

  test "冪等重跑:已寄出的不會重寄" do
    @campaign.deliveries.create!(team: @team, customer: customers(:acme_tom), status: :sent, sent_at: Time.current)

    assert_no_emails do
      CampaignSendJob.perform_now(@campaign)
    end

    assert_equal 1, @campaign.deliveries.count
    assert @campaign.reload.sent?
  end

  test "SMTP 錯誤:Delivery 標 failed、客戶記退信,活動照常完成" do
    CampaignMailer.singleton_class.define_method(:marketing) do |_delivery|
      raise Net::SMTPFatalError.new("550 5.1.1 User unknown")
    end

    begin
      CampaignSendJob.perform_now(@campaign)
    ensure
      CampaignMailer.singleton_class.remove_method(:marketing)
    end

    delivery = @campaign.deliveries.sole
    assert delivery.failed?
    assert_match(/550/, delivery.error_message)
    assert customers(:acme_tom).reload.bounced?
    assert @campaign.reload.sent?
  end

  test "非 sending 狀態不執行" do
    @campaign.update!(status: :draft)

    assert_no_emails do
      CampaignSendJob.perform_now(@campaign)
    end

    assert_equal 0, @campaign.deliveries.count
  end
end
