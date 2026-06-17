class Team < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :customers, dependent: :destroy
  has_many :orders, through: :customers
  has_many :import_jobs, dependent: :destroy
  has_many :tags, dependent: :destroy
  # campaigns 要先於 audiences 銷毀:audience 對 campaigns 是 restrict_with_error
  has_many :campaigns, dependent: :destroy
  has_many :audiences, dependent: :destroy
  has_many :deliveries

  normalizes :slug, with: ->(slug) { slug.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true,
                   length: { in: 2..50 }, format: { with: SLUG_FORMAT }
  validates :monthly_send_quota, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def to_param = slug

  def monthly_sent_count
    deliveries.where(created_at: Time.current.all_month).count
  end

  def remaining_quota
    monthly_send_quota - monthly_sent_count
  end

  def can_send?(count)
    remaining_quota >= count
  end

  # Topbar 額度警示門檻:用量達九成就提醒(UI 指南「快用完時變黃色」)
  def quota_nearly_exhausted?
    monthly_send_quota.positive? && monthly_sent_count >= monthly_send_quota * 0.9
  end
end
