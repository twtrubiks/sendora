# 開發/示範用種子資料。冪等:可重複執行不會產生重複資料。
#
#   bin/rails db:seed                      # 預設 40 位客戶
#   SEED_CUSTOMERS=500 bin/rails db:seed   # 自訂客戶數
#
# 建一個示範團隊與登入帳號,連同客戶 / 訂單 / 標籤 / 分群 / 活動,
# 讓儀表板、分群預覽、發送流程一進來就有資料可看。
# 大量資料(上萬筆)請走 CSV 匯入(客戶頁的匯入功能),那條路用 upsert 快得多。
#
# 只在非 production 執行,避免在正式環境建出 demo 帳號。
return if Rails.env.production?

DEMO_EMAIL = "demo@sendora.test"
DEMO_PASSWORD = "password1234"
CUSTOMER_COUNT = Integer(ENV.fetch("SEED_CUSTOMERS", 40))

ActiveRecord::Base.transaction do
  user = User.find_or_create_by!(email_address: DEMO_EMAIL) { |u| u.password = DEMO_PASSWORD }
  team = Team.find_or_create_by!(slug: "demo") do |t|
    t.name = "示範團隊"
    t.monthly_send_quota = 5000
  end
  Membership.find_or_create_by!(user: user, team: team) { |m| m.role = :owner }

  tags = %w[VIP 新客 回購 電子報].index_with { |name| team.tags.find_or_create_by!(name: name) }

  CUSTOMER_COUNT.times do |i|
    n = format("%04d", i + 1)
    customer = team.customers.find_or_create_by!(email: "customer#{n}@example.com") do |c|
      c.name = "客戶 #{n}"
      c.phone = format("09%08d", i)
    end

    # 每位客戶 0..5 筆訂單(用 i 決定數量,維持冪等)
    (i % 6).times do |j|
      customer.orders.find_or_create_by!(number: "DEMO-#{n}-#{j + 1}") do |o|
        o.team = team
        o.amount = rand(100..5000)
        o.ordered_at = rand(1..180).days.ago
      end
    end

    # 標籤分配(以 i 決定,確保可重複執行結果一致)
    assigned = []
    assigned << tags["VIP"] if (i % 8).zero?
    assigned << tags["新客"] if (i % 5).zero?
    assigned << tags["回購"] if (i % 6) >= 3
    assigned << tags["電子報"] if i.even?
    assigned.each { |tag| CustomerTag.find_or_create_by!(customer: customer, tag: tag) }
  end

  # 幾個退訂 / 退信狀態,讓「可寄送對象」與發送排除邏輯有東西可示範
  team.customers.find_by(email: "customer0001@example.com")&.unsubscribe!
  team.customers.find_by(email: "customer0002@example.com")&.mark_bounced!

  # 分群(動態,不存名單)
  team.audiences.find_or_create_by!(name: "全部客戶") { |a| a.conditions = {} }
  team.audiences.find_or_create_by!(name: "VIP 客戶") { |a| a.conditions = { "tags" => [ "VIP" ] } }
  team.audiences.find_or_create_by!(name: "高消費(累計 ≥ 3000)") do |a|
    a.conditions = { "min_total_spent" => "3000" }
  end

  # 一封草稿活動(對「全部客戶」),可直接進確認頁試發
  all_customers = team.audiences.find_by(name: "全部客戶")
  team.campaigns.find_or_create_by!(name: "示範活動:夏季回饋") do |c|
    c.audience = all_customers
    c.subject = "親愛的 {{name}},夏季優惠來囉"
    c.body = "Hi {{name}},\n\n這是一封示範行銷信,感謝你長期支持。\n\nSendora 團隊"
    c.status = :draft
  end
end

team = Team.find_by(slug: "demo")
puts "✅ 種子完成"
puts "   登入:#{DEMO_EMAIL} / #{DEMO_PASSWORD}"
puts "   團隊:#{team.name}(/t/#{team.slug})"
puts "   客戶 #{team.customers.count}、訂單 #{team.orders.count}、標籤 #{team.tags.count}、" \
     "分群 #{team.audiences.count}、活動 #{team.campaigns.count}"
