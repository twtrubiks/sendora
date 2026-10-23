require "test_helper"

class CampaignsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:alice) }

  test "活動列表" do
    get campaigns_path(team_slug: "acme")
    assert_response :success
    assert_select "td", text: /六月會員回購/
  end

  test "新增與編輯表單頁" do
    get new_campaign_path(team_slug: "acme")
    assert_response :success
    assert_select "select[name='campaign[audience_id]']"

    get edit_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    assert_response :success
    assert_select "input[name='campaign[name]'][value='六月會員回購']"
  end

  test "沒有分群時導去建立分群" do
    sign_in_as users(:bob)
    get new_campaign_path(team_slug: "globex")
    assert_redirected_to audiences_path(team_slug: "globex")
  end

  test "建立草稿後前往發送確認" do
    assert_difference "Campaign.count", 1 do
      post campaigns_path(team_slug: "acme"), params: { campaign: {
        name: "新活動", audience_id: audiences(:acme_all).id, subject: "哈囉", body: "內文"
      } }
    end

    campaign = teams(:acme).campaigns.find_by(name: "新活動")
    assert campaign.draft?
    assert_redirected_to confirm_campaign_path(campaign, team_slug: "acme")
  end

  test "不能綁定別團隊的分群(跨租戶 IDOR)" do
    globex_audience = teams(:globex).audiences.create!(name: "G")

    assert_no_difference "Campaign.count" do
      post campaigns_path(team_slug: "acme"), params: { campaign: {
        name: "偷名單", audience_id: globex_audience.id, subject: "s", body: "b"
      } }
    end
    assert_response :unprocessable_entity

    patch campaign_path(campaigns(:acme_draft), team_slug: "acme"),
          params: { campaign: { audience_id: globex_audience.id } }
    assert_response :unprocessable_entity
    assert_equal audiences(:acme_vips).id, campaigns(:acme_draft).reload.audience_id
  end

  test "確認頁顯示人數與剩餘額度" do
    get confirm_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    assert_response :success
    assert_select "dd", text: /1 位客戶/
    assert_select "button", text: "確認發送"
  end

  test "額度不足時確認按鈕反灰" do
    teams(:acme).update!(monthly_send_quota: 0)

    get confirm_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    assert_select "button[disabled]", text: "確認發送"
    assert_select "span", /超出本月額度/
  end

  test "確認發送:標記 sending 並排入 job" do
    assert_enqueued_with(job: CampaignSendJob) do
      post deliver_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    end

    assert campaigns(:acme_draft).reload.sending?
    assert_redirected_to campaign_path(campaigns(:acme_draft), team_slug: "acme")
  end

  test "同一份草稿被另一個請求搶先送出:不重複排 job" do
    original = Campaign.instance_method(:start_sending)
    # 模擬另一個請求在 require_draft! 之後、start_sending 之前搶先把草稿送出
    Campaign.define_method(:start_sending) do
      Campaign.where(id: id).update_all(status: :sending)
      original.bind_call(self)
    end

    begin
      assert_no_enqueued_jobs do
        post deliver_campaign_path(campaigns(:acme_draft), team_slug: "acme")
      end
    ensure
      Campaign.define_method(:start_sending, original)
    end

    assert_redirected_to campaign_path(campaigns(:acme_draft), team_slug: "acme")
    assert_equal "此活動已經開始發送", flash[:alert]
  end

  test "分群沒有可寄送的客戶時擋下發送" do
    customers(:acme_tom).unsubscribe!   # acme_draft 的分群(VIP)只有 acme_tom

    assert_no_enqueued_jobs do
      post deliver_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    end

    assert_redirected_to confirm_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    assert_equal "此分群目前沒有可寄送的客戶", flash[:alert]
    assert campaigns(:acme_draft).reload.draft?
  end

  test "額度不足時擋下發送" do
    teams(:acme).update!(monthly_send_quota: 0)

    assert_no_enqueued_jobs do
      post deliver_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    end

    assert_redirected_to confirm_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    assert_equal "超出本月發送額度,請聯絡管理者調整", flash[:alert]
    assert campaigns(:acme_draft).reload.draft?
  end

  test "接續寄送:失敗的活動切回 sending 並排入 job" do
    campaign = campaigns(:acme_draft)
    campaign.update!(status: :failed, error_message: "SMTP 認證失敗")

    assert_enqueued_with(job: CampaignSendJob, args: [ campaign ]) do
      post resume_campaign_path(campaign, team_slug: "acme")
    end

    assert_redirected_to campaign_path(campaign, team_slug: "acme")
    assert_equal "已接續發送,先前寄出的不會重寄", flash[:notice]
    assert campaign.reload.sending?
    assert_nil campaign.error_message
  end

  test "接續寄送只限發送失敗的活動" do
    assert_no_enqueued_jobs do
      post resume_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    end

    assert_redirected_to campaign_path(campaigns(:acme_draft), team_slug: "acme")
    assert_equal "只有發送失敗的活動可以接續寄送", flash[:alert]
    assert campaigns(:acme_draft).reload.draft?
  end

  test "接續寄送也檢查額度" do
    campaign = campaigns(:acme_draft)
    campaign.update!(status: :failed)
    teams(:acme).update!(monthly_send_quota: 0)

    assert_no_enqueued_jobs do
      post resume_campaign_path(campaign, team_slug: "acme")
    end

    assert_redirected_to campaign_path(campaign, team_slug: "acme")
    assert_equal "超出本月發送額度,請聯絡管理者調整", flash[:alert]
    assert campaign.reload.failed?
  end

  test "接續寄送被另一個請求搶先:不重複排 job" do
    campaign = campaigns(:acme_draft)
    campaign.update!(status: :failed)
    original = Campaign.instance_method(:start_sending)
    Campaign.define_method(:start_sending) do |**options|
      Campaign.where(id: id).update_all(status: :sending)
      original.bind_call(self, **options)
    end

    begin
      assert_no_enqueued_jobs do
        post resume_campaign_path(campaign, team_slug: "acme")
      end
    ensure
      Campaign.define_method(:start_sending, original)
    end

    assert_equal "此活動已經開始發送", flash[:alert]
  end

  test "失敗的活動頁顯示接續寄送鈕與尚未寄出人數;都寄完了就不顯示" do
    campaign = campaigns(:acme_draft)
    campaign.update!(status: :failed, error_message: "SMTP 認證失敗")

    get campaign_path(campaign, team_slug: "acme")
    assert_select "button", "接續寄送"
    assert_match "還有 1 位尚未寄出", response.body

    campaign.deliveries.create!(team: teams(:acme), customer: customers(:acme_tom), status: :sent)
    get campaign_path(campaign, team_slug: "acme")
    assert_select "button", text: "接續寄送", count: 0
  end

  test "已發送的活動不能再編輯或發送" do
    campaigns(:acme_draft).update!(status: :sent, sent_at: Time.current)

    get edit_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    assert_redirected_to campaign_path(campaigns(:acme_draft), team_slug: "acme")

    assert_no_enqueued_jobs do
      post deliver_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    end
  end

  test "複製活動成新草稿" do
    campaigns(:acme_draft).update!(status: :sent)

    assert_difference "Campaign.count", 1 do
      post duplicate_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    end

    copy = teams(:acme).campaigns.order(:created_at).last
    assert copy.draft?
    assert_equal "六月會員回購(副本)", copy.name
    assert_equal campaigns(:acme_draft).subject, copy.subject
  end

  test "成效頁與成效 CSV" do
    campaign = campaigns(:acme_draft)
    campaign.update!(status: :sent, sent_at: Time.current)
    campaign.deliveries.create!(team: teams(:acme), customer: customers(:acme_tom), status: :sent, sent_at: Time.current)
    campaign.deliveries.create!(team: teams(:acme), customer: customers(:acme_unsub), status: :failed, error_message: "550 user unknown")

    get campaign_path(campaign, team_slug: "acme")
    assert_response :success
    assert_select "td", text: /550 user unknown/
    assert_select "td", text: "tom@example.com", count: 0   # 失敗清單不列寄達的

    get campaign_path(campaign, team_slug: "acme", format: :csv)
    assert_match(/tom@example.com,sent/, response.body)
    assert_match(/unsub@example.com,failed/, response.body)
  end

  test "客戶刪除後,成效頁與 CSV 仍可顯示其發送紀錄" do
    campaign = campaigns(:acme_draft)
    campaign.update!(status: :sent, sent_at: Time.current)
    campaign.deliveries.create!(team: teams(:acme), customer: customers(:acme_tom), status: :failed, error_message: "550")
    customers(:acme_tom).destroy!

    get campaign_path(campaign, team_slug: "acme")
    assert_response :success
    assert_select "td", "(已刪除的客戶)"

    get campaign_path(campaign, team_slug: "acme", format: :csv)
    assert_equal [ "email,status,error,sent_at", ",failed,," ], response.body.lines.map(&:chomp)
  end

  test "草稿可刪,看不到別團隊的活動" do
    assert_difference "Campaign.count", -1 do
      delete campaign_path(campaigns(:acme_draft), team_slug: "acme")
    end

    globex_audience = teams(:globex).audiences.create!(name: "G")
    campaign = teams(:globex).campaigns.create!(audience: globex_audience, name: "G 活動", subject: "s", body: "b")
    get campaign_path(campaign, team_slug: "acme")
    assert_response :not_found
  end
end
