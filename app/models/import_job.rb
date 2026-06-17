class ImportJob < ApplicationRecord
  MAX_FILE_SIZE = 10.megabytes

  belongs_to :team
  belongs_to :user
  has_many :import_failures, dependent: :destroy
  has_one_attached :file

  enum :kind, { customers: 0, orders: 1 }, validate: true
  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  validates :filename, presence: true
  validate :file_must_be_acceptable, on: :create, if: :pending?

  def in_progress? = pending? || processing?

  private
    def file_must_be_acceptable
      unless file.attached?
        errors.add(:file, :blank)
        return
      end

      errors.add(:file, :too_large) if file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, :wrong_type) unless file.filename.extension_with_delimiter.casecmp?(".csv")
    end
end
