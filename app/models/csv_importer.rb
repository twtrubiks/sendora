# CSV 匯入的共同流程:串流逐列解析 → 驗證清洗 → 分批 upsert。
# 子類別實作 required_headers / build_row / flush(batch)。
class CsvImporter
  BATCH_SIZE = 500

  Result = Data.define(:total_rows, :success_count, :failures)
  RowError = Class.new(StandardError)
  FileError = Class.new(StandardError)

  def initialize(import_job)
    @import_job = import_job
    @team = import_job.team
  end

  def run
    total = 0
    successes = 0
    failures = []
    batch = []

    each_row do |row, line_number|
      total += 1
      begin
        batch << build_row(row, line_number)
      rescue RowError => e
        failures << failure_for(line_number, e.message, row)
      end

      if batch.size >= BATCH_SIZE
        flushed, failed = flush(batch)
        successes += flushed
        failures.concat(failed)
        batch = []
      end
    end

    flushed, failed = flush(batch)
    successes += flushed
    failures.concat(failed)

    Result.new(total_rows: total, success_count: successes, failures: failures)
  end

  private
    attr_reader :team

    def each_row
      @import_job.file.open do |tempfile|
        csv = CSV.new(tempfile, headers: true, encoding: "bom|utf-8",
                      header_converters: ->(h) { h.to_s.strip.downcase })
        line_number = 1

        csv.each do |row|
          if line_number == 1
            missing = required_headers - row.headers.compact
            raise FileError, "缺少必要欄位:#{missing.join('、')}" if missing.any?
          end

          line_number += 1
          yield row, line_number
        end
      end
    rescue CSV::MalformedCSVError => e
      raise FileError, "CSV 格式錯誤:#{e.message}"
    end

    def failure_for(line_number, message, row)
      { line_number: line_number, message: message, raw_row: row.to_csv(force_quotes: false).strip }
    end

    def field(row, key)
      row[key].to_s.strip.presence
    end
end
