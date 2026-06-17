# Sendora 實作指南(Rails 8 全家桶)

> Sendora 是一個小團隊自架的輕量 email 行銷工具:匯入客戶與訂單資料、
> 用消費行為切分群、批量發送行銷信、看見成效——定位是 Mailchimp / Klaviyo
> **核心功能**的精簡自架替代(聚焦「分群 + 批量寄送 + 基本成效」,
> 不含自動化流程 flows 與開信/點擊追蹤),給自己擁有訂單資料的小型電商團隊。
> 版本資訊確認日期:2026-06-12。

---

## 1. 範圍

### 做(核心閉環)

1. 多租戶骨架:User / Team / Membership + 角色權限(owner / member 兩種)
2. 客戶資料:Customer / Order + 標籤系統
3. CSV 匯入管線:上傳 → 背景解析直接 upsert → 失敗列留存供檢視(檔案處理完即刪)
4. 分群(Audience):用標籤 / 條件篩出客戶群
5. 行銷活動(Campaign):對 Audience 批量發 Email,記錄發送結果
6. 退訂與退信基本盤:每封信帶退訂連結、公開退訂頁、退信記錄與發送排除
7. 儀表板:即時 SQL 彙總 KPI + 圖表

### 不做(刻意排除)

- 後台管理介面 → 營運操作用 rails console 就夠
- 第二種資料庫 → 只用 PostgreSQL
- 雲端物件儲存 → ActiveStorage Disk 就夠(只有匯入暫存檔一個用途)
- 推薦 / 預測等進階分析 → 所有計算用 SQL
- SMS、LINE、電商平台串接(Shopify 等)→ 留介面,後補
- 點數計費 → 用 Team 的月發送額度欄位取代;真要收錢時再做方案 + 金流 webhook,
  資料模型不衝突
- KPI 預計算(彙總表 + 每日 job)→ 儀表板即時 SQL,慢了再加 Solid Cache
- 排程發送 → 第一版只有立即發送,`scheduled_at` 之後要加不影響主幹
- 開信 / 點擊追蹤 → 成效頁先只看寄達 / 失敗;之後要加 = pixel + 轉址兩個 endpoint
- WebSocket / 即時功能 → 不需要

---

## 2. 技術棧與版本(2026-06 最新穩定版)

| 項目 | 選用 | 版本 |
|---|---|---|
| 語言 | Ruby | 4.0.x(目前 4.0.5;注意:2025-12 起 Ruby 從 3.4 直接跳 4.0,沒有 3.5) |
| 框架 | Rails | 8.1.x(目前 8.1.3) |
| 資料庫 | PostgreSQL | 18.x(目前 18.4;19 還在 beta,不要用) |
| 前端 | Hotwire(Turbo + Stimulus) | Rails 內建,跟隨 turbo-rails / stimulus-rails 最新版 |
| CSS | Tailwind CSS(tailwindcss-rails) | 4.x |
| JS 載入 | importmap-rails(無 Node、無 bundler) | Rails 內建 |
| 靜態資產 | Propshaft | Rails 內建 |
| 背景任務 | Solid Queue | Rails 內建(免 Redis) |
| 快取 | Solid Cache | Rails 內建(免 Redis) |
| 認證 | Rails 內建 authentication generator | `bin/rails generate authentication` |
| 分頁 | pagy | 9.x |
| 圖表 | chartkick + groupdate(底層包 Chart.js) | 5.x / 6.x |
| CSV | csv gem(Ruby 3.4 起非預設 gem,要進 Gemfile) | 最新 |
| 部署 | Kamal + Thruster | 2.x(Rails 內建) |
| 測試 | Minitest + fixtures | Rails 內建 |

外部依賴總清單:**PostgreSQL,沒了**。不需要 Redis、不需要 Node、不需要雲端服務。

#### Solid 三件套存哪裡(免 Redis 的代價)

這三個元件取代 Redis,但**存放位置依環境而異**——開發時多半在行程記憶體裡、不落地到 DB,只有正式環境才真的寫進 PostgreSQL。正式環境的「獨立」是**資料庫(database)層級**:每個元件各自一顆獨立的 database(跟主資料庫 `sendora_production` 平行,不塞進主資料庫),database 裡面才是 table。下表「正式環境」欄位的格式是 `database 名(內含幾張 table)`:

| 元件 | 取代什麼 | 開發環境 | 正式環境(Kamal) |
|---|---|---|---|
| Solid Cache | Redis 快取 | `:memory_store`(行程記憶體)**不進 DB** | 獨立 database `sendora_production_cache`(內含 1 張 table:`solid_cache_entries`) |
| Solid Queue | Sidekiq/Redis 背景工作 | 預設 `:async`(行程內執行緒)**不進 DB** | 獨立 database `sendora_production_queue`(內含 11 張 table:`solid_queue_*`) |
| Solid Cable | Redis pub/sub | `async`(行程內)**不進 DB** | 獨立 database `sendora_production_cable`(內含 1 張 table:`solid_cable_messages`) |

- 切換靠 `config/environments/production.rb`(`cache_store = :solid_cache_store`、`queue_adapter = :solid_queue`、`solid_queue.connects_to`)與 `config/{cache,queue,cable}.yml`;開發環境沒開,所以連 `sendora_development` 看不到任何 `solid_*` 表是正常的。
- 正式機因此共 **4 顆 database**:主資料庫 `sendora_production` + 上述 3 顆;三顆的 schema 來自 `db/{queue,cache,cable}_schema.rb`,部署時 `db:prepare` 各自載入。
- 想在本機觀察背景工作真的寫進 DB,需在 `development.rb` 設 `config.active_job.queue_adapter = :solid_queue` 並把 `solid_queue_*` schema 載入開發資料庫 `sendora_development`(預設不載)。

選 Rails 這套全家桶的理由與邊界(甜蜜點公式、Hotwire 省掉什麼)見 [DESIGN_NOTES.md](DESIGN_NOTES.md) §1。

建專案:

```bash
rails new sendora --database=postgresql --css=tailwind
```

---

## 3. 系統架構

```
                ┌─────────────────────────────────────┐
                │            一台 VPS(Kamal)         │
                │                                     │
 Browser ──────►│  Thruster ──► Puma(Rails 8.1)     │
                │                 ├─ Web(Hotwire)    │
                │                 └─ Solid Queue       │
                │                    (跑在 Puma 內)   │
                │                                     │
                │  PostgreSQL 18(Kamal accessory)    │
                │   ├─ 主資料庫                      │
                │   ├─ queue 資料庫(Solid Queue)     │
                │   ├─ cache 資料庫(Solid Cache)     │
                │   └─ cable 資料庫(Solid Cable)     │
                │                                     │
                │  Volume:/storage(ActiveStorage)   │
                └─────────────────────────────────────┘
```

- 單機部署,Solid Queue 用 `SOLID_QUEUE_IN_PUMA=true` 跑在 Puma 進程內,免獨立 worker。
  量大了再拆成獨立 `bin/jobs` 容器,程式碼不用改。
- 沒有任何 recurring / cron 任務,Solid Queue 只跑事件觸發的 job。
- 上圖只畫到 Thruster;最外層還有 **kamal-proxy** 負責 HTTPS / TLS 與零停機切換。
  完整請求路徑(誰負責 HTTPS、誰扮演 nginx 角色)見 [REQUEST_FLOW.md](REQUEST_FLOW.md)。

---

## 4. 資料模型(約 13 張表)

```
User ──< Session                          # authentication generator 產生
User ──< Membership >── Team              # Membership.role: owner / member
Team ──< 所有業務資料(一律掛 team_id)

Team ──< Customer ──< Order
Team ──< Tag ──< CustomerTag >── Customer # 單純 join table,不用 polymorphic

Team ──< ImportJob ──< ImportFailure      # 只存失敗列,成功的直接進 Customer/Order
Team ──< Audience                         # conditions: jsonb
Team ──< Campaign ──< Delivery >── Customer
```

要點:

- **多租戶用「明確關聯」不用 default_scope**:所有查詢從 `Current.team.customers...` 出發。
  搭配一個 `Current`(ActiveSupport::CurrentAttributes)存 user / team,
  controller 層用 before_action 從 URL 的 team slug 解析並驗證 Membership。
- **標籤系統**:直接 `customer_tags(tag_id, customer_id)` join table + 唯一索引防重複貼標。
  實際上只有客戶會被貼標;真出現第二種要貼標的對象,再改 polymorphic(Rails 裡這個遷移很便宜)。
- **防重複發送**:`Delivery` 加唯一索引 `[campaign_id, customer_id]`,
  用 `insert_all`(skip duplicates)或 `create_or_find_by` 落地。
- **發送額度**:Team 加 `monthly_send_quota` 整數欄位(不建額度表)。
  檢查 = 「本月 Delivery 數 + 本次人數 ≤ 額度」,一個 query method 搞定(見 §5.8)。
- **退訂 / 退信是欄位不是表**:Customer 加 `unsubscribed_at`、`bounced_at`。
  發送解析時一律排除兩者非空的客戶(寫在 query object 裡,不靠呼叫端記得)。
- 所有表都有 `created_at/updated_at`(Rails 預設就有)。

---

## 5. 各模組實作要點

### 5.1 認證 + 多租戶

- `bin/rails generate authentication` 產生 User / Session / 密碼重設,夠用。
- 路由:`/t/:team_slug/...` 巢狀所有業務資源。
- 權限:`Membership.role` 用 Rails enum,只有 owner / member 兩種。
  controller 寫一個 `require_owner!` helper 就夠(管成員、刪團隊、改額度才用到)。

### 5.2 客戶 + 標籤

- Customer 唯一鍵:`[team_id, email]`(或 phone),匯入時 upsert。
- 標準 CRUD + Turbo:列表篩選用 Turbo Frame 包住表格,排序 / 分頁 / 搜尋都是普通 GET。

### 5.3 CSV 匯入管線

原則:**成功的列直接進資料庫,只有失敗列留下紀錄,檔案處理完即刪**。

1. 上傳(限 10MB):檔案暫掛 ActiveStorage(Disk),建 ImportJob(status: pending),
   enqueue `ImportProcessJob`。
2. `ImportProcessJob`(Solid Queue):串流逐列解析 → 驗證清洗 →
   分批 upsert 到 Customer / Order;失敗列寫入 `import_failures`(列號 + 人話原因)。
   跑完更新 ImportJob 統計(成功 N / 失敗 M)並 **purge 掉原始檔**。
3. 匯入結果頁:Turbo Frame 自動刷新進度;失敗列直接在頁面列出原因,可下載失敗清單。

### 5.4 Audience 分群

- `conditions` 存 jsonb,例如:`{"tags": ["VIP"], "min_total_spent": 1000, "ordered_after": "2026-01-01"}`。
- 一個 query object(`AudienceQuery`)把 conditions 轉成 ActiveRecord scope chain。
- 編輯頁:Stimulus controller 做動態條件列(新增 / 移除條件),
  「預覽人數」按鈕打一個回傳 count 的 endpoint,Turbo Frame 更新數字。
- Audience 不存成員名單,**發送當下才解析**(動態分群)。

### 5.5 Campaign 發送(核心難點)

- 狀態機用 enum:draft → sending → sent / failed(沒有 scheduled,第一版只有立即發送)。
- 發送流程:**單一 `CampaignSendJob`,不做 fan-out**——fan-out 派發是幾十萬封規模
  才需要的設計,月額度等級的量,一個 job 線性寄完就好:
  1. 額度檢查(§5.8),不足把 Campaign 標 failed 並附原因。
  2. 解析 Audience → `insert_all` Deliveries(唯一索引防重,寫入可分批)。
  3. `find_each` 逐筆 ActionMailer 寄送 → 更新 Delivery 狀態(sent / failed)。
  4. job 跑完即把 Campaign 標記 sent——沒有跨批次完成判定,狀態流轉線性到不會錯。
- **防併發重跑**:Solid Queue 原生支援
  `limits_concurrency to: 1, key: ->(campaign) { campaign.id }`,
  同一個 Campaign 同時只會有一個發送 job 在跑。
- **中斷恢復(冪等重跑)**:`find_each` 只掃 `status: :pending` 的 Delivery,
  每筆寄出後立即更新該筆狀態;job 中途死掉(部署重啟、OOM)重新 enqueue 時,
  已寄的不會重寄——配合唯一索引,整段發送流程冪等。
- 成效:只統計寄達 / 失敗。開信 / 點擊追蹤之後要加,就是一個 pixel endpoint +
  一個轉址 endpoint,各自更新 Delivery 的時間戳,資料模型不用動。
- **退訂(法規入場券)**:每封信 footer 自動帶退訂連結,token 用 Rails 內建
  `generates_token_for :unsubscribe`(簽名 + 可設過期)。公開退訂 endpoint 不需登入,
  一鍵寫入 `unsubscribed_at`。
- **退信**:第一版只做同步處理——SMTP 寄送拋錯即記 Delivery failed + Customer `bounced_at`,
  之後寄送自動排除。供應商的非同步 bounce webhook(Mailgun 等)後補,接上時更新同一個欄位。
- **退訂 / 退信的套件選項(M4 動工時二選一)**:`mailkick` 一個 gem 涵蓋退訂名單、
  List-Unsubscribe one-click header(RFC 8058,Gmail / Yahoo 對 bulk sender 強制要求)、
  供應商 bounce / spam 檢舉同步(Mailgun / Postmark / SES);代價是改用它的 opt-out 表,
  取代上面的 `unsubscribed_at` / `bounced_at` 欄位設計。**若維持手刻**:記得自己補
  List-Unsubscribe header,且供應商 webhook 不能拖太晚——bounce / complaint 多為非同步回報,
  SMTP 同步拋錯抓不到,SES 退信率超標會直接停帳號。
- 開發環境收信:`letter_opener_web` gem,掛在 `/letter_opener` 路由
  (Docker 開發時容器內開不了本機瀏覽器,不用 letter_opener)。

### 5.6 儀表板(即時 SQL)

- **不做預計算表**。KPI 即時 SQL 彙總,這個資料量級下毫無壓力;
  真的慢了再包一層 Solid Cache(`Rails.cache.fetch(key, expires_in: 5.minutes)`)。
- 圖表用 **chartkick + groupdate**(底層仍是 Chart.js),日期彙總 SQL 與前端掛載全代勞:

```erb
<%= line_chart Current.team.deliveries.group_by_day(:created_at).count %>
```

  不用自寫日期彙總的 query object、不用 chart Stimulus controller、不用 JSON API。
- KPI 卡片是普通 partial;日期區間切換:GET 表單 + Turbo Frame,零自訂 JS。

### 5.7 報表匯出

- 不存檔、不用背景任務:controller 直接串流。

```ruby
response.headers["Content-Disposition"] = 'attachment; filename="report.csv"'
self.response_body = Enumerator.new do |y|
  y << CSV.generate_line(headers)
  scope.find_each { |row| y << CSV.generate_line(row.to_csv_row) }
end
```

- 幾十萬列以內都沒問題。真的要超大報表再回頭加「背景產檔 + ActiveStorage」。

### 5.8 發送額度

- Team 一個欄位:`monthly_send_quota`(預設例如 5,000,調整用 console)。
- 一個 query method:

```ruby
class Team < ApplicationRecord
  def remaining_quota
    monthly_send_quota - deliveries.where(created_at: Time.current.all_month).count
  end

  def can_send?(count) = remaining_quota >= count
end
```

- `CampaignSendJob` 開頭檢查,不足直接把 Campaign 標 failed 並附原因。
- 之後要做真計費:加 Plan / Subscription / 金流 webhook 即可,
  額度檢查的呼叫點不變,現有資料模型不衝突。

---

## 6. 前端約定(Hotwire)

- 預設一切 server-rendered + Turbo Drive,**先假設不需要寫 JS**。
- Turbo Frame 用在:列表篩選 / 分頁、modal 表單、Audience 人數預覽、匯入進度。
- Turbo Stream 用在:表單成功後更新列表(一般 CRUD 的 create/destroy 回 stream)。
- Stimulus controller 預估只需要 3~4 個:
  `conditions`(分群動態條件列)、`confirm`、`dropdown`(圖表由 chartkick 代勞,不用自寫)。

---

## 7. 背景任務一覽(Solid Queue)

| Job | 觸發 |
|---|---|
| ImportProcessJob | 上傳後 enqueue |
| CampaignSendJob | 使用者按「發送」 |

只有兩個,全部事件觸發,**沒有 recurring 排程、沒有 fan-out**。

---

## 8. 部署(Kamal,單機)

- 一台 VPS(2C/4G 起步即可)+ 一個 domain。
- `config/deploy.yml` 重點:
  - app server 環境變數 `SOLID_QUEUE_IN_PUMA=true`
  - accessory:`postgres:18`(掛 volume);正式環境會有 **4 顆 database**(主資料庫 + Solid 三件套各一顆),細節見 §2「Solid 三件套存哪裡」
  - app 掛 volume:`sendora_storage:/rails/storage`(ActiveStorage Disk 用)
  - `proxy: ssl: true`(kamal-proxy 自動 Let's Encrypt)
- 反向代理與 HTTPS 的分層(kamal-proxy / Thruster / Puma 各管什麼)見 [REQUEST_FLOW.md](REQUEST_FLOW.md)。
- 部署 = `kamal deploy`;完整單機部署步驟、維運 cheatsheet 與選型理由見 [KAMAL_DEPLOY.md](KAMAL_DEPLOY.md)。
- 「誰執行部署、在哪 build」的控制端定位(本機 vs CI / GitHub Actions)見 [DEPLOY_CONTROL_PLANE.md](DEPLOY_CONTROL_PLANE.md)。
- 寄信走 SMTP 服務商(Mailgun / Postmark / SES 皆可),記得設好網域的
  SPF / DKIM / DMARC,這是寄達率的基本盤。
- 備份:cron 跑 `pg_dump` + rsync `storage/`,第一版這樣就夠。

---

## 9. Milestones

| # | 內容 | 驗收 |
|---|---|---|
| M1 | rails new、認證、Team / Membership、權限 | 註冊 → 建團隊 → 邀成員 → 切換團隊 |
| M2 | Customer / Order CRUD + CSV 匯入管線 | 上傳萬筆 CSV,背景匯入,失敗列有錯誤訊息 |
| M3 | 標籤 + Audience 分群 + 人數預覽 | 條件組合篩客戶,預覽即時更新 |
| M4 | Campaign + Email 批量發送 + 額度 + 退訂 | 對分群發信,Delivery 不重複,額度不足擋發送,退訂後不再收信 |
| M5 | 儀表板 + CSV 匯出 + Kamal 上線 | KPI 卡 + 趨勢圖 + 串流下載;正式環境跑起來 |

M1–M4 約 5~6 週(一人全職)跑通核心閉環,M5 再 1~2 週,全程 **6~8 週**。

---

## 10. 開發環境(Docker)與程式碼品質

### 開發環境:Docker Compose

- 根目錄 `compose.yaml`(app 容器 + postgres 18,自成一體):
  `docker compose up` 一行起服務,一次性指令走 `docker compose run --rm web …`
  (`bin/rails test`、`bin/rails console`、`bin/rubocop` 等)。
- **不要拿 production Dockerfile 開發**:Kamal 用的那份是
  `BUNDLE_WITHOUT="development"`、資產預編譯的產線映像,開發一律走 `compose.yaml`。
- 開發收信走 `letter_opener_web`(§5.5),瀏覽器開 `/letter_opener` 看信。
- 注意 `kamal deploy` 在主機跑(需要 docker build / ssh),不在開發容器內跑。

### 程式碼品質(`rails new` 預設就有,別刪)

| 工具 | 用途 | 來源 |
|---|---|---|
| RuboCop(rubocop-rails-omakase) | 風格 / lint,Rails 官方 omakase 規則 | `rails new` 預設 |
| Brakeman | Rails 安全靜態掃描 | `rails new` 預設 |
| `bin/importmap audit` | JS 相依漏洞掃描 | importmap-rails 內建 |
| `bin/bundler-audit` | gem 已知漏洞掃描 | `rails new` 預設 |
| GitHub Actions CI | 上述四項 + 測試(`.github/workflows/ci.yml`) | `rails new` 預設 |
| `bin/ci`(`config/ci.rb`) | 本機一鍵跑同一套,合併前跑綠再推 | Rails 8.1 內建 |

- 原則:**沿用 omakase 預設,不自訂 cop**;有風格爭議跟官方走,把心力留給業務邏輯。
- 維護成本只有「保持綠燈」:CI 紅了就修,不累積。

---

## 11. 版本來源

- Rails 8.1.3:https://rubyonrails.org/category/releases
- Ruby 4.0.5(3.4 之後直接跳 4.0):https://www.ruby-lang.org/en/downloads/releases/
- PostgreSQL 18.4:https://www.postgresql.org/about/news/postgresql-184-1710-1614-1518-and-1423-released-3297/
- 各版本 EOL 對照:https://endoflife.date/rails 、https://endoflife.date/ruby 、https://endoflife.date/postgresql

動工前用 `ruby -v`、`rails -v`、官網 release 頁再確認一次小版號即可。
