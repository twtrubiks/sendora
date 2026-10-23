class Delivery < ApplicationRecord
  belongs_to :team
  belongs_to :campaign
  belongs_to :customer, optional: true   # 客戶刪除後紀錄保留,customer 為 nil

  enum :status, { pending: 0, sent: 1, failed: 2 }

  validates :customer_id, uniqueness: { scope: :campaign_id }, allow_nil: true
end
