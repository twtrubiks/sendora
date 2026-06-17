class Tag < ApplicationRecord
  belongs_to :team
  has_many :customer_tags, dependent: :destroy
  has_many :customers, through: :customer_tags

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { scope: :team_id }, length: { maximum: 50 }
end
