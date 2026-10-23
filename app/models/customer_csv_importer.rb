# 欄位:email(必填)、name、phone。以 [team_id, email] upsert:
# name / phone 留空不會清掉既有值;檔內同一 email 重複時,後面的列有值才覆蓋。
class CustomerCsvImporter < CsvImporter
  private
    def required_headers = %w[ email ]

    def build_row(row, _line_number)
      email = field(row, "email")&.downcase
      raise RowError, "email 不可空白" if email.nil?
      raise RowError, "email 格式錯誤:#{email}" unless email.match?(URI::MailTo::EMAIL_REGEXP)

      name = field(row, "name")
      phone = field(row, "phone")
      raise RowError, "name 不可超過 100 個字元" if name && name.length > 100
      raise RowError, "phone 不可超過 30 個字元" if phone && phone.length > 30

      { team_id: team.id, email: email, name: name, phone: phone }
    end

    def flush(batch)
      return [ 0, [] ] if batch.empty?

      rows = batch.group_by { |attrs| attrs[:email] }.values
                  .map { |dups| dups.reduce { |merged, attrs| merged.merge(attrs.compact) } }
      Customer.upsert_all(rows, unique_by: %i[ team_id email ], on_duplicate: Arel.sql(<<~SQL))
        name = COALESCE(EXCLUDED.name, customers.name),
        phone = COALESCE(EXCLUDED.phone, customers.phone),
        updated_at = EXCLUDED.updated_at
      SQL
      [ batch.size, [] ]
    end
end
