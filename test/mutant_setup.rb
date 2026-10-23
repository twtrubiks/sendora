# mutant 專用載入檔(config/mutant.yml 的 requires),bin/rails test 不會載入。

# 必須先於 test_helper:mutant 會把 Minitest.autorun 換成 no-op。
# 晚載入的話 Rails 已註冊 at_exit 自動跑測試,每個變異的子行程結束時都以非 0 退出,
# mutant 把結果視為無效,所有變異都會被誤判為存活
require "mutant/integration/minitest"
require_relative "test_helper"

# subject 要從已載入的類別裡找,測試環境預設不 eager load
Rails.application.eager_load!

# 每個測試都可以拿來殺任何 app 類別的變異:量的是「整套測試抓不抓得到」,
# 而不是單元測試各自的隔離度(controller / integration 測試也算數)
Rails.autoloaders.main.all_expected_cpaths.values
     .map { |cpath| cpath.split("::").first }.uniq
     .each { |name| ActiveSupport::TestCase.cover("#{name}*") }
