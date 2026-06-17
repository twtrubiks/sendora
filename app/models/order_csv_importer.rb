# 欄位:email、number、amount、ordered_at(皆必填)。
# email 必須是已存在的客戶;以 [team_id, number] upsert,重複列以後者為準。
class OrderCsvImporter < CsvImporter
  private
    def required_headers = %w[ email number amount ordered_at ]

    def build_row(row, line_number)
      email = field(row, "email")&.downcase
      number = field(row, "number")
      raise RowError, "email 不可空白" if email.nil?
      raise RowError, "number(訂單編號)不可空白" if number.nil?
      raise RowError, "number 不可超過 100 個字元" if number.length > 100

      amount = begin
        BigDecimal(field(row, "amount") || "")
      rescue ArgumentError, TypeError
        raise RowError, "amount 不是數字:#{field(row, 'amount')}"
      end
      raise RowError, "amount 不可為負數" if amount.negative?

      ordered_at = Time.zone.parse(field(row, "ordered_at").to_s)
      raise RowError, "ordered_at 不是有效日期:#{field(row, 'ordered_at')}" if ordered_at.nil?

      { line_number: line_number, email: email,
        attrs: { team_id: team.id, number: number, amount: amount, ordered_at: ordered_at } }
    rescue ArgumentError
      raise RowError, "ordered_at 不是有效日期:#{field(row, 'ordered_at')}"
    end

    # 訂單要先把 email 換成 customer_id,所以失敗列在 flush 階段才能確定
    def flush(batch)
      return [ 0, [] ] if batch.empty?

      customer_ids = team.customers.where(email: batch.map { |item| item[:email] })
                         .pluck(:email, :id).to_h
      failures = []
      rows = []

      batch.each do |item|
        if (customer_id = customer_ids[item[:email]])
          rows << item[:attrs].merge(customer_id: customer_id)
        else
          failures << { line_number: item[:line_number],
                        message: "找不到客戶 #{item[:email]},請先匯入客戶資料",
                        raw_row: nil }
        end
      end

      rows = rows.reverse.uniq { |attrs| attrs[:number] }.reverse
      Order.upsert_all(rows, unique_by: %i[ team_id number ]) if rows.any?
      [ batch.size - failures.size, failures ]
    end
end
