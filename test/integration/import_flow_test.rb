require "test_helper"

# M2 驗收旅程:上傳 CSV → 背景匯入 → 結果頁有成功 / 失敗統計與原因
class ImportFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "上傳客戶 CSV 到看見匯入結果" do
    sign_in_as users(:alice)

    perform_enqueued_jobs do
      post import_jobs_path(team_slug: "acme"), params: {
        import_job: { kind: "customers", file: fixture_file_upload("customers.csv", "text/csv") }
      }
    end

    job = teams(:acme).import_jobs.order(:created_at).last
    assert job.completed?
    assert_equal 4, job.total_rows
    assert_equal 3, job.success_count
    assert_equal 1, job.failure_count
    assert teams(:acme).customers.exists?(email: "good1@example.com")

    get import_job_path(job, team_slug: "acme")
    assert_response :success
    assert_select "td", text: /email 格式錯誤/
  end

  test "先匯客戶再匯訂單" do
    sign_in_as users(:alice)

    perform_enqueued_jobs do
      post import_jobs_path(team_slug: "acme"), params: {
        import_job: { kind: "orders", file: fixture_file_upload("orders.csv", "text/csv") }
      }
    end

    job = teams(:acme).import_jobs.order(:created_at).last
    assert job.completed?
    assert_equal 1, job.success_count
    assert_equal 2, job.failure_count
    assert customers(:acme_tom).orders.exists?(number: "ORD-100")
  end
end
