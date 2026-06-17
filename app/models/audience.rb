class Audience < ApplicationRecord
  belongs_to :team
  has_many :campaigns, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }

  # 動態分群:不存名單,每次使用時用 conditions 重新解析
  def customers
    AudienceQuery.new(team, conditions).customers
  end
end
