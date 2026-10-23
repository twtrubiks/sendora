class Campaign < ApplicationRecord
  belongs_to :team
  belongs_to :audience
  has_many :deliveries, dependent: :destroy

  enum :status, { draft: 0, sending: 1, sent: 2, failed: 3 }

  validates :name, presence: true, length: { maximum: 100 }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :body, presence: true
  validate :audience_must_belong_to_team

  # 發送對象:解析分群後,一律排除已退訂與退信的客戶
  def recipients
    audience.customers.merge(Customer.contactable)
  end

  # 重跑(冪等)時只需為還沒有 Delivery 的對象扣額度。
  # 要排除已刪除客戶留下的 NULL:NOT IN 子查詢只要含 NULL,整個條件就不成立
  def pending_recipients_count
    recipients.where.not(id: deliveries.where.not(customer_id: nil).select(:customer_id)).count
  end

  # 條件式更新當鎖:同一份草稿被同時送出兩次(雙擊、兩個分頁),
  # 只有一個請求搶得到 → sending,另一個拿到 false、不會再排 job(兩邊都 reload 成 DB 現況)。
  # from: :failed 用於中斷後接續寄送,同時清掉上次的錯誤訊息
  def start_sending(from: :draft)
    claimed = Campaign.where(id: id, status: from)
                      .update_all(status: :sending, error_message: nil, updated_at: Time.current) == 1
    reload
    claimed
  end

  # 接續寄送會寄給的人數:中斷時留下的 pending,加上分群裡還沒有 Delivery 的對象
  def resumable_count
    deliveries.pending.count + pending_recipients_count
  end

  def duplicate
    team.campaigns.new(audience: audience, name: "#{name}(副本)", subject: subject, body: body)
  end

  private
    # 防止跨租戶 IDOR:audience_id 可由參數竄改,必須綁在同一團隊
    # (DB 另有 (audience_id, team_id) 複合外鍵當第二道防線,擋繞過 validation 的寫入)。
    # 只在指派變動時檢查:萬一 DB 已有髒資料,job 更新 status 的 update! 才不會跟著炸
    def audience_must_belong_to_team
      return unless audience_id_changed? || team_id_changed?

      errors.add(:audience, :wrong_team) if audience && team_id && audience.team_id != team_id
    end
end
