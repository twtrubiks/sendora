class Order < ApplicationRecord
  belongs_to :team
  belongs_to :customer

  validates :number, presence: true, uniqueness: { scope: :team_id }, length: { maximum: 100 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :ordered_at, presence: true
end
