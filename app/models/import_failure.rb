class ImportFailure < ApplicationRecord
  belongs_to :import_job

  validates :line_number, presence: true
  validates :message, presence: true
end
