class CustomerTag < ApplicationRecord
  belongs_to :customer
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :customer_id }
end
