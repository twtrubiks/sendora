# Sendora 設計筆記(技術選型與架構取捨)

> 這份文件收錄「**為什麼這樣選、這樣設計**」的討論。
> 跟 [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) 的「怎麼做」分工:
> 那邊是模組級的實作要點,這邊是框架 / 架構級的取捨理由。新的討論往後累加。

## 目錄

- [1. 為什麼是 Rails(全家桶與甜蜜點)](#1-為什麼是-rails全家桶與甜蜜點)

---

## 1. 為什麼是 Rails(全家桶與甜蜜點)

### 全家桶裝了什麼

Rails 的賣點不是某個元件特別強,是**整桶一起端上來、口味先幫你配好(omakase)**:
一套心智模型、一個 repo、一次部署。

| 需求 | Rails 內建 | 省掉的東西 |
|---|---|---|
| ORM / 資料關聯 | Active Record | 挑 ORM、接 migration 工具 |
| 表單 | form helper + strong params + validations | 表單函式庫 |
| 寄信 | Action Mailer | 第三方寄信 SDK 的膠水 |
| 背景工作 / 快取 / WebSocket | Solid Queue / Cache / Cable | **Redis** |
| 認證 | 內建 authentication generator | Devise |
| 前端互動 | Hotwire(Turbo + Stimulus) | **整套 SPA + 前端 API** |
| 部署 | Kamal + Thruster | PaaS / k8s |

Rails 8 把全家桶做更大,正是為了 DHH 講的「the one-person framework」——讓一個人扛得動全棧。
Sendora 的外部依賴因此收斂到只剩 PostgreSQL(見 [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) §2)。

### 甜蜜點公式

> **適合 = Web 應用 + 重 CRUD + 重表單 + 重資料關聯**

這是 Rails 的本命。從 migration → 能跑的表單 → 帶驗證的持久化,程式碼量小到誇張,別的框架很難打。

這條公式的軸是「**應用的形狀**」,不是「複雜度」。「重 CRUD / 重表單 / 重資料關聯」**不等於「簡單」**——
這類應用可以非常複雜(Sendora 本身就是:多租戶、權限關聯、批量寄送、儀表板)。
Rails 撐不住的從來不是「太複雜」,而是「**形狀不對**」(見下方〈甜蜜點的邊界〉)。
別把「適合 Rails」讀成「只能做簡單網頁」。

### Hotwire 省掉的到底是什麼

Hotwire 真正省掉的不是「前端工程師」,而是「**另一套前端 codebase,以及維護它的人**」。
前端的活(HTML / CSS、Stimulus、必要時手寫 JS)一樣得做;省掉的是這一整套重複工:
建一套 API(REST/JSON、GraphQL 隨你挑)+ 一個在 client 端把領域模型再實作一遍的
app(TS 是常見選擇)+ 後端一改、前端就得跟著改,沒完沒了。

但 Hotwire 不是萬能。互動本質是「換頁、送表單、更新某個區塊」時它完勝;一旦要真正的
client 端狀態(畫布編輯器、拖拉試算表、離線、協作游標、複雜的 optimistic UI),
它撐不住,還是得 Stimulus + 真 JS 元件,甚至 React island。

### 甜蜜點的邊界(反證用)

知道它「不適合什麼」,才站得住「為什麼這個專案適合」:

| 情境 | 為什麼 Rails 不再是甜蜜點 |
|---|---|
| API-first / mobile-first,web 只是配角 | 伺服器渲染 HTML 的優勢蒸發,你還是得做一套 API |
| 重計算 / 資料工程 / ML | Rails 是膠水不是引擎 |
| 極限規模 + 團隊高度分工 | monolith「一人掌握全局」的優勢反轉成包袱 |

### 落回 Sendora

回頭對照上面三條邊界——Sendora 不是 API-first(web 是主角)、不是重計算 / ML(是膠水活)、
規模與分工也都還在 monolith 撐得住的範圍。三條都不沾,所以——

正中靶心:多租戶 SaaS、客戶 / 訂單 / 分群 / 活動的 CRUD、帶驗證的表單、
User / Team / Membership 的關聯、交易信 + 批量寄送、SQL 儀表板。
整個需求**沒有一處想變成 SPA**。

唯二可能「破格」、未來真要做時得動到真 JS 的地方,先點名免得日後驚訝:

1. **郵件模板編輯器**——若要做到所見即所得(WYSIWYG),這塊可能需要真前端元件。目前不在範圍。
2. **寄送進度 / 退信即時儀表板**——這個還在守備範圍內,Turbo Streams 或 Action Cable 就能吃下,不算破格。

結論:不是「因為只會 Rails 所以用 Rails」,是**需求形狀剛好長成 Rails 的模子**。
