class Delivery < ApplicationRecord
  belongs_to :team
  belongs_to :campaign
  belongs_to :customer

  enum :status, { pending: 0, sent: 1, failed: 2 }

  validates :customer_id, uniqueness: { scope: :campaign_id }
end
