require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  test "audience 必須屬於同一團隊" do
    globex_audience = teams(:globex).audiences.create!(name: "G")
    campaign = campaigns(:acme_draft)
    campaign.audience = globex_audience

    assert_not campaign.valid?
    assert campaign.errors[:audience].any?
  end

  test "複合外鍵在 DB 層擋掉略過 validation 的跨團隊綁定" do
    globex_audience = teams(:globex).audiences.create!(name: "G")
    campaign = campaigns(:acme_draft)
    campaign.audience_id = globex_audience.id

    assert_raises(ActiveRecord::InvalidForeignKey) do
      campaign.save!(validate: false)
    end
  end

  test "start_sending:同一份草稿只有第一次搶得到 draft → sending" do
    campaign = campaigns(:acme_draft)
    stale = Campaign.find(campaign.id)

    travel 1.minute do
      assert campaign.start_sending
      assert campaign.sending?
      assert_equal Time.current, campaign.updated_at
    end
    assert Campaign.find(campaign.id).sending?

    assert_not stale.start_sending
    assert stale.sending?
  end

  test "start_sending:非草稿不會被改回 sending" do
    campaign = campaigns(:acme_draft)
    campaign.update!(status: :sent, sent_at: Time.current)

    assert_not campaign.start_sending
    assert campaign.reload.sent?
  end

  test "start_sending(from: :failed):失敗的活動可以接續,並清掉上次的錯誤訊息" do
    campaign = campaigns(:acme_draft)
    campaign.update!(status: :failed, error_message: "SMTP 認證失敗")

    assert_not campaign.start_sending, "預設只從 draft 切換"
    assert campaign.failed?

    assert campaign.start_sending(from: :failed)
    assert campaign.sending?
    assert_nil campaign.error_message
  end

  test "resumable_count:中斷時留下的 pending,加上還沒有 Delivery 的對象" do
    campaign = campaigns(:acme_draft)
    campaign.update!(audience: audiences(:acme_all), status: :failed)
    amy = teams(:acme).customers.create!(email: "amy@example.com")
    teams(:acme).customers.create!(email: "ben@example.com")
    campaign.deliveries.create!(team: teams(:acme), customer: customers(:acme_tom), status: :sent)
    campaign.deliveries.create!(team: teams(:acme), customer: amy, status: :pending)

    # tom 已寄出不算;amy 的 pending + ben 還沒有 Delivery;acme_unsub 已退訂不算
    assert_equal 2, campaign.resumable_count
  end

  test "pending_recipients_count:有已刪除客戶留下的紀錄(customer_id 為 NULL)時照常計算" do
    campaign = campaigns(:acme_draft)
    campaign.update!(audience: audiences(:acme_all), status: :failed)
    gone = teams(:acme).customers.create!(email: "gone@example.com")
    campaign.deliveries.create!(team: teams(:acme), customer: gone, status: :sent)
    gone.destroy!

    # acme_tom 還沒有 Delivery(acme_unsub 已退訂不算)
    assert_equal 1, campaign.pending_recipients_count
  end
end
