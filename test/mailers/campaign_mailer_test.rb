require "test_helper"

class CampaignMailerTest < ActionMailer::TestCase
  setup do
    @delivery = Delivery.new(team: teams(:acme), campaign: campaigns(:acme_draft), customer: customers(:acme_tom))
    @mail = CampaignMailer.marketing(@delivery)
  end

  test "收件人與個人化主旨、內文" do
    assert_equal [ "tom@example.com" ], @mail.to
    assert_equal "Tom 陳 您好,六月專屬優惠", @mail.subject
    assert_match "親愛的 Tom 陳", @mail.text_part.body.to_s
    assert_match "親愛的 Tom 陳", @mail.html_part.body.to_s
  end

  test "沒有姓名時用「貴賓」" do
    customer = teams(:acme).customers.create!(email: "noname@example.com")
    delivery = Delivery.new(team: teams(:acme), campaign: campaigns(:acme_draft), customer: customer)
    mail = CampaignMailer.marketing(delivery)
    assert_match "貴賓 您好", mail.subject
  end

  test "信末帶退訂連結,token 可反查客戶" do
    body = @mail.text_part.body.to_s
    token = body[%r{unsubscribe/([^\s]+)}, 1]
    assert token.present?
    assert_equal customers(:acme_tom), Customer.find_by_token_for(:unsubscribe, token)
  end

  test "帶 RFC 8058 List-Unsubscribe one-click headers" do
    assert_match %r{unsubscribe/}, @mail.header["List-Unsubscribe"].value
    assert_equal "List-Unsubscribe=One-Click", @mail.header["List-Unsubscribe-Post"].value
  end
end
