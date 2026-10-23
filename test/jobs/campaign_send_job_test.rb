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
    with_mailer_raising(Net::SMTPFatalError.new("550 5.1.1 User unknown")) do
      CampaignSendJob.perform_now(@campaign)
    end

    delivery = @campaign.deliveries.sole
    assert delivery.failed?
    assert_match(/550/, delivery.error_message)
    assert customers(:acme_tom).reload.bounced?
    assert @campaign.reload.sent?
  end

  test "地址格式錯誤(501 5.1.3,Net::SMTP 拋 SMTPSyntaxError)也記退信" do
    with_mailer_raising(Net::SMTPSyntaxError.new("501 5.1.3 Bad recipient address syntax")) do
      CampaignSendJob.perform_now(@campaign)
    end

    assert @campaign.deliveries.sole.failed?
    assert customers(:acme_tom).reload.bounced?
  end

  test "信箱停用(5.2.x,多行回應)也記退信" do
    with_mailer_raising(Net::SMTPFatalError.new("552-5.2.2 The email account that you tried to reach is over quota")) do
      CampaignSendJob.perform_now(@campaign)
    end

    assert @campaign.deliveries.sole.failed?
    assert customers(:acme_tom).reload.bounced?
  end

  test "非收件人層級的 5xx(寄件身分未驗證、無增強狀態碼):Delivery 標 failed,但不記退信" do
    [ "554 5.7.1 Message rejected: Email address is not verified",
      "550 Requested action not taken" ].each do |response|
      @campaign.deliveries.delete_all
      @campaign.update!(status: :sending)

      with_mailer_raising(Net::SMTPFatalError.new(response)) do
        CampaignSendJob.perform_now(@campaign)
      end

      @campaign.reload
      assert @campaign.sent?, response
      assert @campaign.deliveries.sole.failed?, response
      assert_not customers(:acme_tom).reload.bounced?, response
    end
  end

  test "非 SMTP 錯誤:Delivery 標 failed、不記退信,其他人照寄" do
    with_mailer_raising(ArgumentError.new("bad template")) do
      CampaignSendJob.perform_now(@campaign)
    end

    delivery = @campaign.deliveries.sole
    assert delivery.failed?
    assert_equal "bad template", delivery.error_message
    assert_not customers(:acme_tom).reload.bounced?
    assert @campaign.reload.sent?
  end

  test "寄件端錯誤(認證失敗、伺服器忙碌、連線中斷):立刻中止,未寄的留 pending,不記退信" do
    @campaign.update!(audience: audiences(:acme_all))
    @team.customers.create!(email: "amy@example.com", name: "Amy")

    [ Net::SMTPAuthenticationError.new("535 5.7.8 Authentication credentials invalid"),
      Net::SMTPServerBusy.new("421 4.7.0 Try again later"),
      EOFError.new("end of file reached"),
      Errno::ECONNREFUSED.new,
      Net::ReadTimeout.new ].each do |error|
      @campaign.deliveries.delete_all
      @campaign.update!(status: :sending, error_message: nil)

      attempts = with_mailer_raising(error) do
        CampaignSendJob.perform_now(@campaign)
      end

      assert_equal 1, attempts, error.class.name
      @campaign.reload
      assert @campaign.failed?, error.class.name
      assert_includes @campaign.error_message, error.class.name
      assert_equal 2, @campaign.deliveries.pending.count, error.class.name
      assert_not @team.customers.where.not(bounced_at: nil).exists?, error.class.name
    end
  end

  test "收件人暫時性 4xx(greylisting、信箱暫滿):只該筆標 failed、不記退信,其他人照寄、活動照常完成" do
    @campaign.update!(audience: audiences(:acme_all))
    @team.customers.create!(email: "amy@example.com", name: "Amy")

    [ "450 4.1.8 Sender address rejected: Domain not found, try again later",
      "452 4.2.2 Mailbox full",
      "450-4.2.1 The user you are trying to contact is receiving mail too quickly" ].each do |response|
      @campaign.deliveries.delete_all
      @campaign.update!(status: :sending, error_message: nil)

      attempts = with_mailer_raising(Net::SMTPServerBusy.new(response)) do
        CampaignSendJob.perform_now(@campaign)
      end

      assert_equal 2, attempts, response
      @campaign.reload
      assert @campaign.sent?, response
      assert_equal 2, @campaign.deliveries.failed.count, response
      assert_equal 0, @campaign.deliveries.pending.count, response
      assert_not @team.customers.where.not(bounced_at: nil).exists?, response
    end
  end

  test "非收件人層級的 4xx(服務暫停、限流、無增強狀態碼):仍整個中止" do
    @campaign.update!(audience: audiences(:acme_all))
    @team.customers.create!(email: "amy@example.com", name: "Amy")

    [ "421 4.3.2 Service not available, closing transmission channel",
      "450 4.7.1 Too many messages from this sender",
      "454 Throttling failure: Maximum sending rate exceeded" ].each do |response|
      @campaign.deliveries.delete_all
      @campaign.update!(status: :sending, error_message: nil)

      attempts = with_mailer_raising(Net::SMTPServerBusy.new(response)) do
        CampaignSendJob.perform_now(@campaign)
      end

      assert_equal 1, attempts, response
      assert @campaign.reload.failed?, response
      assert_equal 2, @campaign.deliveries.pending.count, response
    end
  end

  test "非預期的錯誤(如 DB 錯誤):活動標 failed 並附通用訊息,不會卡在 sending" do
    Delivery.singleton_class.define_method(:insert_all) do |*|
      raise ActiveRecord::StatementInvalid, "connection lost"
    end

    begin
      assert_no_emails do
        CampaignSendJob.perform_now(@campaign)
      end
    ensure
      Delivery.singleton_class.remove_method(:insert_all)
    end

    @campaign.reload
    assert @campaign.failed?
    assert_equal "發送過程發生未預期的錯誤,請聯絡系統管理者", @campaign.error_message
  end

  test "Delivery 建立後才退訂或退信的客戶不寄,刪掉該筆 Delivery(不佔額度),其他人照寄" do
    amy = @team.customers.create!(email: "amy@example.com")
    ben = @team.customers.create!(email: "ben@example.com")
    [ customers(:acme_tom), amy, ben ].each do |customer|
      @campaign.deliveries.create!(team: @team, customer: customer, status: :pending)
    end
    customers(:acme_tom).unsubscribe!
    amy.mark_bounced!

    assert_emails 1 do
      CampaignSendJob.perform_now(@campaign)
    end

    assert_equal [ "ben@example.com" ], ActionMailer::Base.deliveries.last.to
    assert_equal [ ben ], @campaign.deliveries.map(&:customer)
    assert @campaign.reload.sent?
  end

  test "非 sending 狀態不執行" do
    @campaign.update!(status: :draft)

    assert_no_emails do
      CampaignSendJob.perform_now(@campaign)
    end

    assert_equal 0, @campaign.deliveries.count
  end

  private
    # 讓 CampaignMailer.marketing 一律拋出 error,回傳被呼叫的次數
    def with_mailer_raising(error)
      attempts = 0
      CampaignMailer.singleton_class.define_method(:marketing) do |_delivery|
        attempts += 1
        raise error
      end

      begin
        yield
      ensure
        CampaignMailer.singleton_class.remove_method(:marketing)
      end

      attempts
    end
end
