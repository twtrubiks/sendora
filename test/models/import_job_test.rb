require "test_helper"

class ImportJobTest < ActiveSupport::TestCase
  test "檔案剛好 10MB 可以上傳,多 1 byte 就擋下" do
    assert build_import_job(size: ImportJob::MAX_FILE_SIZE).valid?

    import_job = build_import_job(size: ImportJob::MAX_FILE_SIZE + 1)
    assert_not import_job.valid?
    assert import_job.errors.added?(:file, :too_large)
  end

  test "副檔名不是 .csv 擋下(不分大小寫)" do
    assert build_import_job(filename: "customers.CSV").valid?

    import_job = build_import_job(filename: "customers.txt")
    assert_not import_job.valid?
    assert import_job.errors.added?(:file, :wrong_type)
  end

  test "沒有附檔擋下" do
    import_job = teams(:acme).import_jobs.new(user: users(:alice), kind: :customers, filename: "customers.csv")

    assert_not import_job.valid?
    assert import_job.errors.added?(:file, :blank)
  end

  private
    def build_import_job(size: 10, filename: "customers.csv")
      teams(:acme).import_jobs.new(
        user: users(:alice), kind: :customers, filename: filename,
        file: { io: StringIO.new("a" * size), filename: filename, content_type: "text/csv" }
      )
    end
end
