class ImportProcessJob < ApplicationJob
  queue_as :default

  def perform(import_job)
    return unless import_job.pending?

    import_job.update!(status: :processing)
    importer = import_job.customers? ? CustomerCsvImporter : OrderCsvImporter
    result = importer.new(import_job).run

    result.failures.each_slice(500) do |slice|
      import_job.import_failures.insert_all(slice)
    end

    import_job.update!(status: :completed,
                       total_rows: result.total_rows,
                       success_count: result.success_count,
                       failure_count: result.failures.size)
  rescue CsvImporter::FileError => e
    import_job.update!(status: :failed, error_message: e.message)
  rescue => e
    Rails.logger.error("[ImportProcessJob] import_job=#{import_job.id} #{e.class}: #{e.message}")
    import_job.update!(status: :failed, error_message: "匯入過程發生未預期的錯誤,請聯絡系統管理者")
  ensure
    import_job.file.purge if import_job.file.attached?
  end
end
