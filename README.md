# Sendora

[![Ruby](https://img.shields.io/badge/Ruby-4.0-CC342D.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1-D30001.svg)](https://rubyonrails.org/)
[![Hotwire](https://img.shields.io/badge/Hotwire-Turbo%20%2B%20Stimulus-5cb85c.svg)](https://hotwired.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-336791.svg)](https://www.postgresql.org/)
[![Solid Queue](https://img.shields.io/badge/Solid%20Queue-1.4-990000.svg)](https://github.com/rails/solid_queue)
[![Solid Cache](https://img.shields.io/badge/Solid%20Cache-1.0-990000.svg)](https://github.com/rails/solid_cache)
[![Kamal](https://img.shields.io/badge/Kamal-2.11-7B61FF.svg)](https://kamal-deploy.org/)
[![Thruster](https://img.shields.io/badge/Thruster-0.1-F97316.svg)](https://github.com/basecamp/thruster)
[![Puma](https://img.shields.io/badge/Puma-8-2EA44F.svg)](https://puma.io/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)

小團隊自架的輕量 email 行銷工具:匯入客戶與訂單資料、用消費行為分群、
批量發送行銷信、看見成效。

Mailchimp / Klaviyo **核心功能**的精簡自架替代——
聚焦「分群 + 批量寄送 + 基本成效」,**不做自動化流程(flows)與開信/點擊追蹤**;
給自己擁有訂單資料的小型電商團隊。

這也是一份**練習作品**:刻意挑一個有真實複雜度的題目,把 Rails 8 全家桶
(Hotwire、Solid Queue / Cache)與 Kamal 單機部署從零實作到上線。

完整規格與取捨見 [docs/IMPLEMENTATION_GUIDE.md](docs/IMPLEMENTATION_GUIDE.md),
介面見 [docs/UI_UX_GUIDE.md](docs/UI_UX_GUIDE.md)。

## 功能

- **多租戶**:User / Team / Membership,角色只有 owner / member 兩種;
  所有業務資源掛在 `/t/:team_slug/` 之下,書籤與分享連結不會跑錯團隊。
- **客戶與訂單**:客戶有 CRUD、搜尋、標籤,訂單掛在客戶底下(新增 / 刪除);
  CSV 背景匯入(上限 10MB,串流逐列解析、分批 upsert,
  失敗列留存列號與原因、可下載清單,原始檔處理完即刪)。
- **分群(Audience)**:條件存 jsonb(標籤、累計消費、訂單數、購買與建立日期區間,
  彼此 AND),不存名單、發送當下動態解析;編輯時可即時預覽人數。
- **行銷活動(Campaign)**:草稿 → 全螢幕確認頁(明列對象人數與剩餘額度)→
  背景批量發送。Delivery 以 `[campaign_id, customer_id]` 唯一索引防重複寄送,
  發送 job 只掃 pending、逐筆更新狀態,中斷重跑不會重寄;
  同一活動同時只允許一個發送 job。支援 `{{name}}` 個人化。
- **發送額度**:每團隊一個月額度欄位,發送前檢查、不足擋下;
  Topbar 常駐本月用量,達九成變黃提醒。額度調整走 rails console,不做計費。
- **退訂與退信**:每封信帶簽名退訂連結(30 天過期)與
  List-Unsubscribe one-click header(RFC 8058);公開退訂頁不需登入。
  SMTP 同步寄送錯誤記入 `bounced_at`,之後的發送自動排除。
- **儀表板**:KPI 卡與營收/訂單趨勢圖(chartkick + groupdate),
  即時 SQL 彙總,不做預計算表。
- **CSV 匯出**:客戶名單、活動發送結果、匯入失敗列,皆為 controller 串流下載,
  不存檔、不走背景任務。

## 畫面預覽

### 儀表板

> 網址皆帶 `/t/:team_slug/` 前綴(多租戶,見上方「功能」),截圖網址為 demo 租戶

![儀表板](https://cdn.imgpile.com/f/hUN5i42_xl.png)

### 分群(Audience)

![分群](https://cdn.imgpile.com/f/MzUUCLW_xl.png)

### 行銷活動(Campaign)

![行銷活動確認頁](https://cdn.imgpile.com/f/eLNrlgN_xl.png)

### 信件預覽(letter_opener,開發 / 測試環境)

> 開發與測試環境寄出的信不會真的送出,改由 letter_opener 攔截檢視;正式環境不啟用。

![letter_opener 信件預覽](https://cdn.imgpile.com/f/TAzgoAO_xl.png)

## 技術棧

Rails 8.1 全家桶:Hotwire(Turbo + Stimulus)、Tailwind CSS 4、
Solid Queue / Solid Cache、Kamal + Thruster、pagy、chartkick + groupdate。
外部依賴只有 PostgreSQL 18——不需要 Redis、不需要 Node、不需要雲端服務。

為什麼是 Rails(全家桶適合什麼、邊界在哪)見 [docs/DESIGN_NOTES.md](docs/DESIGN_NOTES.md)。

對外的反向代理與 HTTPS 分層(kamal-proxy 管 TLS、Thruster 扮演 nginx 角色、Puma 跑程式)
見 [docs/REQUEST_FLOW.md](docs/REQUEST_FLOW.md)。

## 開發環境

主機只需要 Docker,不用裝 Ruby。根目錄 `compose.yaml` 自帶 app 容器與 postgres 18,一行起服務:

```bash
docker compose up        # 首次自動裝 gem、建資料庫,再起服務
```

瀏覽 <http://localhost:3000>;開發環境寄出的信不會真的送出,
在 <http://localhost:3000/letter_opener> 檢視。一次性指令走 `run`:

```bash
docker compose run --rm web bin/rails db:seed    # 灌示範資料,登入 demo@sendora.test / password1234
docker compose run --rm web bin/rails test       # 測試
docker compose run --rm web bin/rails console     # console
docker compose down                               # 停(加 -v 連 DB、gem volume 一起清)
```

## 測試與品質檢查

`bin/ci` 一鍵跑完整套,合併前保持綠燈:

```bash
bin/rubocop          # 風格(rubocop-rails-omakase,不自訂 cop)
bin/brakeman         # 安全靜態掃描
bin/bundler-audit    # gem 已知漏洞
bin/importmap audit  # JS 相依漏洞
bin/rails test       # 測試
```

`bin/ci`(`config/ci.rb`)除上述檢查外,起手會先跑 `Setup`,最後以
`db:seed:replant` 重建種子驗證 `db/seeds.rb` 可重跑,合計 7 步。

測試目前涵蓋 model / controller / job / mailer / integration 層(150 個;
integration 為 HTTP 層流程串接,非瀏覽器測試),
尚無 system test,瀏覽器端 JS 行為未有自動化測試。

## 部署(Kamal,單機)

`config/deploy.yml` 已含單機部署設定:postgres 18 accessory(掛 volume)、
kamal-proxy 自動 SSL、ActiveStorage volume、Solid Queue 跑在 Puma 進程內
(`SOLID_QUEUE_IN_PUMA`),免獨立 worker。

完整的單機部署步驟、維運 cheatsheet 與選型理由見 [docs/KAMAL_DEPLOY.md](docs/KAMAL_DEPLOY.md);

「誰執行部署、在哪 build」的控制端定位(本機 vs CI / GitHub Actions)見
[docs/DEPLOY_CONTROL_PLANE.md](docs/DEPLOY_CONTROL_PLANE.md)。

上線前需要自行填入:

- `deploy.yml` 內的 server IP、網域(`APP_HOST`)、image registry、
  SMTP 服務商(`SMTP_ADDRESS`)與寄件人(`MAILER_FROM`,網域需通過 SPF / DKIM 驗證)
- 部署機環境變數(經 `.kamal/secrets` 讀取):`SENDORA_DATABASE_PASSWORD`、
  `SMTP_USERNAME`、`SMTP_PASSWORD`

注意:正式上線前請在自己的環境依部署步驟完整驗證一遍。

## 已知限制

- 只有立即發送,沒有排程發送(`scheduled_at` 之後要加不影響主幹)。
- 成效只統計寄達/失敗,沒有開信、點擊追蹤。
- 邀請成員僅接受已註冊使用者的 email,不會寄邀請信。
- 退信只處理 SMTP 同步錯誤;供應商的非同步 bounce webhook 未實作,
  使用 SES 等服務商時需留意退信率回報的缺口。
- 沒有後台管理介面,營運操作(調額度等)走 rails console。

## Donation

文章都是我自己研究內化後原創，如果有幫助到您，也想鼓勵我的話，歡迎請我喝一杯咖啡 :laughing:

綠界科技ECPAY ( 不需註冊會員 )

![alt tag](https://payment.ecpay.com.tw/Upload/QRCode/201906/QRCode_672351b8-5ab3-42dd-9c7c-c24c3e6a10a0.png)

[贊助者付款](http://bit.ly/2F7Jrha)

歐付寶 ( 需註冊會員 )

![alt tag](https://i.imgur.com/LRct9xa.png)

[贊助者付款](https://payment.opay.tw/Broadcaster/Donate/9E47FDEF85ABE383A0F5FC6A218606F8)

## 贊助名單

[贊助名單](https://github.com/twtrubiks/Thank-you-for-donate)
