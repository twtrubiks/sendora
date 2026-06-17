require "test_helper"

class ImportProcessJobTest < ActiveJob::TestCase
  test "匯入客戶:成功列直接 upsert,失敗列留下原因,檔案處理完即刪" do
    job = build_import_job(kind: :customers, csv: <<~CSV)
      email,name,phone
      good1@example.com,客戶一,0911111111
      BAD-EMAIL,壞客戶,
      Good2@Example.com,客戶二,
      ,沒有信箱,
    CSV

    assert_difference "teams(:acme).customers.count", 2 do
      ImportProcessJob.perform_now(job)
    end

    job.reload
    assert job.completed?
    assert_equal 4, job.total_rows
    assert_equal 2, job.success_count
    assert_equal 2, job.failure_count

    messages = job.import_failures.order(:line_number).pluck(:line_number, :message)
    assert_equal 3, messages.first.first
    assert_match(/email 格式錯誤/, messages.first.last)
    assert_match(/email 不可空白/, messages.last.last)

    customer = teams(:acme).customers.find_by(email: "good2@example.com")
    assert_equal "客戶二", customer.name

    assert_not job.file.attached?
  end

  test "匯入客戶:email 已存在時更新資料(upsert),檔內重複以後者為準" do
    job = build_import_job(kind: :customers, csv: <<~CSV)
      email,name,phone
      tom@example.com,新名字,0987654321
      dup@example.com,第一筆,
      dup@example.com,第二筆,
    CSV

    assert_difference "teams(:acme).customers.count", 1 do
      ImportProcessJob.perform_now(job)
    end

    assert_equal "新名字", customers(:acme_tom).reload.name
    assert_equal "第二筆", teams(:acme).customers.find_by(email: "dup@example.com").name
    assert_equal 3, job.reload.success_count
  end

  test "匯入客戶:缺少必要欄位整批失敗" do
    job = build_import_job(kind: :customers, csv: "name,phone\n小明,0912\n")

    assert_no_difference "Customer.count" do
      ImportProcessJob.perform_now(job)
    end

    job.reload
    assert job.failed?
    assert_match(/缺少必要欄位:email/, job.error_message)
    assert_not job.file.attached?
  end

  test "匯入訂單:成功 upsert,找不到客戶與格式錯誤列留下原因" do
    job = build_import_job(kind: :orders, csv: <<~CSV)
      email,number,amount,ordered_at
      tom@example.com,ORD-100,999,2026-06-01
      ghost@example.com,ORD-101,500,2026-06-02
      tom@example.com,ORD-102,not-a-number,2026-06-03
      tom@example.com,ORD-103,100,not-a-date
    CSV

    assert_difference "Order.count", 1 do
      ImportProcessJob.perform_now(job)
    end

    job.reload
    assert job.completed?
    assert_equal 4, job.total_rows
    assert_equal 1, job.success_count
    assert_equal 3, job.failure_count

    order = customers(:acme_tom).orders.find_by(number: "ORD-100")
    assert_equal 999, order.amount

    messages = job.import_failures.pluck(:message).join("\n")
    assert_match(/找不到客戶 ghost@example.com/, messages)
    assert_match(/amount 不是數字/, messages)
    assert_match(/ordered_at 不是有效日期/, messages)
  end

  test "匯入訂單:同編號 upsert 更新金額" do
    job = build_import_job(kind: :orders, csv: <<~CSV)
      email,number,amount,ordered_at
      tom@example.com,ORD-1,777,2026-06-05
    CSV

    assert_no_difference "Order.count" do
      ImportProcessJob.perform_now(job)
    end

    assert_equal 777, orders(:acme_tom_first).reload.amount
  end

  test "已處理過的 job 不會重跑" do
    job = build_import_job(kind: :customers, csv: "email\nx@example.com\n", status: :completed)

    assert_no_difference "Customer.count" do
      ImportProcessJob.perform_now(job)
    end
  end

  private
    def build_import_job(kind:, csv:, status: :pending, team: teams(:acme))
      job = team.import_jobs.new(kind: kind, status: status, user: users(:alice), filename: "test.csv")
      job.file.attach(io: StringIO.new(csv), filename: "test.csv", content_type: "text/csv")
      job.save!
      job
    end
end
