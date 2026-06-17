require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "fixture 有效" do
    assert teams(:acme).valid?
  end

  test "name 必填" do
    team = Team.new(name: "", slug: "ok-slug")
    assert_not team.valid?
    assert team.errors[:name].any?
  end

  test "slug 必填且只允許小寫英文、數字與連字號" do
    %w[ Bad\ Slug -starts-with-dash ends-with-dash- double--dash 中文 a ].each do |slug|
      team = Team.new(name: "團隊", slug: slug)
      assert_not team.valid?, "#{slug.inspect} 應該無效"
    end

    %w[ acme2 my-team a-b-c 99 ].each do |slug|
      team = Team.new(name: "團隊", slug: slug)
      assert team.valid?, "#{slug.inspect} 應該有效:#{team.errors.full_messages}"
    end
  end

  test "slug 唯一,且先轉小寫再比對" do
    team = Team.new(name: "另一個", slug: " ACME ")
    assert_not team.valid?
    assert team.errors[:slug].any?
  end

  test "to_param 回傳 slug" do
    assert_equal "acme", teams(:acme).to_param
  end

  test "monthly_send_quota 不可為負數" do
    team = Team.new(name: "團隊", slug: "quota-team", monthly_send_quota: -1)
    assert_not team.valid?
    assert team.errors[:monthly_send_quota].any?
  end

  test "quota_nearly_exhausted? 用量達九成才為真,額度為零不警示" do
    team = teams(:acme)
    team.update!(monthly_send_quota: 2)
    campaign = campaigns(:acme_draft)

    assert_not team.quota_nearly_exhausted?

    campaign.deliveries.create!(team: team, customer: customers(:acme_tom), status: :sent, sent_at: Time.current)
    assert_not team.quota_nearly_exhausted?, "1/2 = 50% 不該警示"

    campaign.deliveries.create!(team: team, customer: customers(:acme_unsub), status: :failed)
    assert team.quota_nearly_exhausted?, "2/2 = 100% 應該警示"

    team.update!(monthly_send_quota: 0)
    assert_not team.quota_nearly_exhausted?
  end
end
