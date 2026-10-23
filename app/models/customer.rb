class Customer < ApplicationRecord
  belongs_to :team
  has_many :orders, dependent: :destroy
  has_many :customer_tags, dependent: :destroy
  has_many :tags, through: :customer_tags

  # 刪除客戶不改寫發送紀錄:已寄出 / 失敗的 Delivery 留著(本月額度、活動成效不變),
  # 只斷開關聯並清掉可能含 email 的錯誤訊息;還沒寄的直接刪掉
  has_many :deliveries
  before_destroy :detach_deliveries

  normalizes :email, with: ->(e) { e.strip.downcase }

  # 退訂連結 token:簽名、不過期(幾個月前的舊信也要能退訂);email 變更即失效
  generates_token_for :unsubscribe do
    email
  end

  # 可寄送對象:排除已退訂與退信
  scope :contactable, -> { where(unsubscribed_at: nil, bounced_at: nil) }

  validates :email, presence: true, uniqueness: { scope: :team_id },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 100 }
  validates :phone, length: { maximum: 30 }

  scope :search, ->(query) {
    next all if query.blank?

    q = "%#{sanitize_sql_like(query.strip)}%"
    where("customers.email ILIKE :q OR customers.name ILIKE :q", q: q)
  }

  def unsubscribed? = unsubscribed_at.present?
  def bounced? = bounced_at.present?
  def contactable? = !unsubscribed? && !bounced?

  def unsubscribe!
    update!(unsubscribed_at: Time.current) unless unsubscribed?
  end

  def mark_bounced!
    update!(bounced_at: Time.current) unless bounced?
  end

  private
    def detach_deliveries
      deliveries.pending.delete_all
      deliveries.update_all(customer_id: nil, error_message: nil, updated_at: Time.current)
    end
end
