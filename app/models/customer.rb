class Customer < ApplicationRecord
  belongs_to :team
  has_many :orders, dependent: :destroy
  has_many :customer_tags, dependent: :destroy
  has_many :tags, through: :customer_tags

  has_many :deliveries, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }

  # 退訂連結 token:簽名 + 30 天過期;email 變更即失效
  generates_token_for :unsubscribe, expires_in: 30.days do
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

  def unsubscribe!
    update!(unsubscribed_at: Time.current) unless unsubscribed?
  end

  def mark_bounced!
    update!(bounced_at: Time.current) unless bounced?
  end
end
