require "test_helper"

class CampaignsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:alice) }

  test "活動列表" do
    get campaigns_path(team_slug: "acme")
    assert_response :success
    assert_select "td", text: /六月會員回購/
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

  test "額度不足時擋下發送" do
    teams(:acme).update!(monthly_send_quota: 0)

    assert_no_enqueued_jobs do
      post deliver_campaign_path(campaigns(:acme_draft), team_slug: "acme")
    end

    assert campaigns(:acme_draft).reload.draft?
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

    get campaign_path(campaign, team_slug: "acme", format: :csv)
    assert_match(/tom@example.com,sent/, response.body)
    assert_match(/unsub@example.com,failed/, response.body)
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
