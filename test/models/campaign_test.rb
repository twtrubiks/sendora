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
end
