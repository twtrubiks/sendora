class ImportJobsController < ApplicationController
  include TeamContext

  TEMPLATES = {
    "customers" => "email,name,phone\nalice@example.com,王小明,0912345678\n",
    "orders" => "email,number,amount,ordered_at\nalice@example.com,ORD-0001,1280,2026-01-31\n"
  }.freeze

  def index
    @pagy, @import_jobs = pagy(Current.team.import_jobs.order(created_at: :desc))
    @import_job = Current.team.import_jobs.new
  end

  def create
    file = params.dig(:import_job, :file)
    @import_job = Current.team.import_jobs.new(
      kind: params.dig(:import_job, :kind),
      user: Current.user,
      file: file,
      filename: file.respond_to?(:original_filename) ? file.original_filename : ""
    )

    if @import_job.save
      ImportProcessJob.perform_later(@import_job)
      redirect_to import_job_path(@import_job), notice: "檔案已上傳,開始背景匯入"
    else
      @pagy, @import_jobs = pagy(Current.team.import_jobs.order(created_at: :desc))
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @import_job = Current.team.import_jobs.find(params[:id])

    respond_to do |format|
      format.html { @pagy, @failures = pagy(@import_job.import_failures.order(:line_number)) }
      format.csv { stream_failures_csv }
    end
  end

  def template
    kind = TEMPLATES.key?(params[:kind]) ? params[:kind] : "customers"
    send_data TEMPLATES[kind], filename: "sendora_#{kind}_template.csv", type: "text/csv"
  end

  private
    def stream_failures_csv
      response.headers["Content-Type"] = "text/csv; charset=utf-8"
      response.headers["Content-Disposition"] = %(attachment; filename="import_#{@import_job.id}_failures.csv")
      failures = @import_job.import_failures.order(:line_number)
      self.response_body = Enumerator.new do |yielder|
        yielder << CSV.generate_line([ "line_number", "reason", "raw_row" ])
        failures.find_each do |failure|
          yielder << CSV.generate_line([ failure.line_number, failure.message, failure.raw_row ])
        end
      end
    end
end
