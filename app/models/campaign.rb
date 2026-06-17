class Campaign < ApplicationRecord
  belongs_to :team
  belongs_to :audience
  has_many :deliveries, dependent: :destroy

  enum :status, { draft: 0, sending: 1, sent: 2, failed: 3 }

  validates :name, presence: true, length: { maximum: 100 }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :body, presence: true

  # 發送對象:解析分群後,一律排除已退訂與退信的客戶
  def recipients
    audience.customers.merge(Customer.contactable)
  end

  # 重跑(冪等)時只需為還沒有 Delivery 的對象扣額度
  def pending_recipients_count
    recipients.where.not(id: deliveries.select(:customer_id)).count
  end

  def duplicate
    team.campaigns.new(audience: audience, name: "#{name}(副本)", subject: subject, body: body)
  end
end
