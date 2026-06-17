class CampaignMailer < ApplicationMailer
  def marketing(delivery)
    @campaign = delivery.campaign
    @customer = delivery.customer
    @body_text = personalize(@campaign.body, @customer)
    @unsubscribe_url = unsubscribe_url(@customer.generate_token_for(:unsubscribe))

    # RFC 8058 one-click 退訂,Gmail / Yahoo 對 bulk sender 的硬性要求
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail to: @customer.email, subject: personalize(@campaign.subject, @customer)
  end

  private
    def personalize(text, customer)
      text.gsub("{{name}}", customer.name.presence || "貴賓")
    end
end
