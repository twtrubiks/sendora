class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :team

  enum :role, { member: 0, owner: 1 }, validate: true

  validates :user_id, uniqueness: { scope: :team_id }
end
