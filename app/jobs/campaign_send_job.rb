require "net/smtp"

class CampaignSendJob < ApplicationJob
  # 寄件端的問題(SMTP 帳密錯、伺服器忙碌或限流、連線中斷):換下一位收件人也會失敗,
  # 繼續寄只會把整份名單都記成 failed,所以整個中止,未寄的 Delivery 留在 pending
  SENDER_ERRORS = [
    Net::SMTPAuthenticationError, Net::SMTPServerBusy,
    IOError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError
  ].freeze

  # 4xx 裡的例外:增強狀態碼 4.1.x(地址暫時無法投遞、greylisting)/ 4.2.x(信箱暫滿、收信過於頻繁)
  # 只是這一位收件人暫時收不到,換下一位照寄。若也跟著中止,整個活動會卡在這一位身上,
  # 接續寄送再撞到同一位又中止。不記退信(不是永久失敗),只把該筆記成 failed
  RECIPIENT_TEMPORARY_FAILURE = /\A4\d\d[ -]4\.[12]\.\d+/

  # RFC 3463 增強狀態碼 5.1.x(地址不存在、格式錯誤)/ 5.2.x(信箱停用、已滿)才是收件人本身的永久失敗,
  # 不論 Net::SMTP 拋的是 SMTPFatalError(550)還是 SMTPSyntaxError(501)。
  # 其餘 5xx(如 5.7.x 寄件身分未驗證、拒絕轉送)是寄件端設定問題,記成退信會誤殺整份名單
  RECIPIENT_REJECTION = /\A5\d\d[ -]5\.[12]\.\d+/

  queue_as :default
  # 同一個 Campaign 同時只會有一個發送 job 在跑(Solid Queue)。
  # duration 要遠大於一次發送的耗時:預設 3 分鐘一過,被擋住的 job 就會放行而併發重寄
  limits_concurrency to: 1, key: ->(campaign) { campaign.id }, duration: 1.day

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
  rescue *SENDER_ERRORS => e
    Rails.logger.error("[CampaignSendJob] campaign=#{campaign.id} aborted #{e.class}: #{e.message}")
    campaign.update!(status: :failed,
                     error_message: "寄信伺服器連線或認證失敗(#{e.class}),已中止發送。請檢查 SMTP 設定後接續寄送")
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
        # Delivery 建立後才退訂或退信的(接續寄送、長時間發送途中):不寄,也不佔額度
        unless delivery.customer.contactable?
          delivery.destroy!
          next
        end

        begin
          CampaignMailer.marketing(delivery).deliver_now
          delivery.update!(status: :sent, sent_at: Time.current)
        rescue Net::SMTPServerBusy => e
          raise unless recipient_temporary_failure?(e)
          delivery.update!(status: :failed, error_message: e.message.truncate(255))
        rescue *SENDER_ERRORS
          raise
        rescue => e
          delivery.update!(status: :failed, error_message: e.message.truncate(255))
          delivery.customer.mark_bounced! if bounce?(e)
        end
      end
    end

    def bounce?(error)
      error.message.match?(RECIPIENT_REJECTION)
    end

    def recipient_temporary_failure?(error)
      error.message.match?(RECIPIENT_TEMPORARY_FAILURE)
    end
end
