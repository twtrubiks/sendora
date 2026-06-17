require "test_helper"

class ImportJobsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:alice) }

  test "匯入首頁:上傳表單與歷史紀錄" do
    get import_jobs_path(team_slug: "acme")
    assert_response :success
  end

  test "上傳 CSV 建立 ImportJob 並排入背景處理" do
    assert_enqueued_with(job: ImportProcessJob) do
      assert_difference "ImportJob.count", 1 do
        post import_jobs_path(team_slug: "acme"), params: {
          import_job: { kind: "customers", file: fixture_file_upload("customers.csv", "text/csv") }
        }
      end
    end

    job = teams(:acme).import_jobs.order(:created_at).last
    assert job.pending?
    assert_equal "customers.csv", job.filename
    assert_redirected_to import_job_path(job, team_slug: "acme")
  end

  test "非 CSV 檔被擋下" do
    assert_no_enqueued_jobs do
      assert_no_difference "ImportJob.count" do
        post import_jobs_path(team_slug: "acme"), params: {
          import_job: { kind: "customers", file: fixture_file_upload("not_csv.txt", "text/plain") }
        }
      end
    end

    assert_response :unprocessable_entity
  end

  test "沒選檔案被擋下" do
    assert_no_difference "ImportJob.count" do
      post import_jobs_path(team_slug: "acme"), params: { import_job: { kind: "customers" } }
    end
    assert_response :unprocessable_entity
  end

  test "詳情頁列出失敗列,並可下載失敗清單 CSV" do
    job = teams(:acme).import_jobs.create!(
      kind: :customers, user: users(:alice), filename: "done.csv",
      status: :completed, total_rows: 3, success_count: 2, failure_count: 1
    )
    job.import_failures.create!(line_number: 3, message: "email 格式錯誤:xx", raw_row: "xx,名字,")

    get import_job_path(job, team_slug: "acme")
    assert_response :success
    assert_select "td", text: /email 格式錯誤/

    get import_job_path(job, team_slug: "acme", format: :csv)
    assert_response :success
    assert_match(/email 格式錯誤/, response.body)
    assert_match(/line_number/, response.body)
  end

  test "下載範本 CSV" do
    get template_import_jobs_path(team_slug: "acme", kind: "orders")
    assert_response :success
    assert_match(/ordered_at/, response.body)
  end

  test "看不到別的團隊的匯入(404)" do
    job = teams(:globex).import_jobs.create!(kind: :customers, user: users(:bob), filename: "g.csv", status: :completed)
    get import_job_path(job, team_slug: "acme")
    assert_response :not_found
  end
end
