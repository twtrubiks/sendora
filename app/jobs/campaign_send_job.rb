class CampaignSendJob < ApplicationJob
  queue_as :default
  # 同一個 Campaign 同時只會有一個發送 job 在跑(Solid Queue)
  limits_concurrency to: 1, key: ->(campaign) { campaign.id }

  def perform(campaign)
    return unless campaign.sending?

    unless campaign.team.can_send?(campaign.pending_recipients_count)
      campaign.update!(status: :failed,
                       error_message: "超出本月發送額度(剩餘 #{campaign.team.remaining_quota} 封),未發送")
      return
    end

    create_deliveries(campaign)
    deliver_pending(campaign)

    campaign.update!(status: :sent, sent_at: Time.current)
  rescue => e
    Rails.logger.error("[CampaignSendJob] campaign=#{campaign.id} #{e.class}: #{e.message}")
    campaign.update!(status: :failed, error_message: "發送過程發生未預期的錯誤,請聯絡系統管理者")
  end

  private
    # 唯一索引 [campaign_id, customer_id] + skip duplicates:重跑不會重複建立
    def create_deliveries(campaign)
      campaign.recipients.in_batches(of: 500) do |batch|
        rows = batch.ids.map do |customer_id|
          { team_id: campaign.team_id, campaign_id: campaign.id, customer_id: customer_id }
        end
        Delivery.insert_all(rows, unique_by: %i[ campaign_id customer_id ]) if rows.any?
      end
    end

    # 只掃 pending、每筆寄出後立即更新狀態:job 中途死掉重跑也不會重寄
    def deliver_pending(campaign)
      campaign.deliveries.pending.includes(:customer).find_each do |delivery|
        begin
          CampaignMailer.marketing(delivery).deliver_now
          delivery.update!(status: :sent, sent_at: Time.current)
        rescue => e
          delivery.update!(status: :failed, error_message: e.message.truncate(255))
          delivery.customer.mark_bounced! if smtp_error?(e)
        end
      end
    end

    def smtp_error?(error)
      error.is_a?(Net::SMTPError) || error.is_a?(IOError)
    end
end
