# 刪除團隊會連帶刪掉所有客戶、訂單、活動與發送紀錄,資料多時會拖過 request 逾時,所以放背景做。
# 呼叫端會先移除所有成員,在這之前團隊就已經沒人能進入
class TeamDestroyJob < ApplicationJob
  queue_as :default
  # 重複排入時,第二個 job 執行時團隊已經不在了
  discard_on ActiveJob::DeserializationError

  def perform(team)
    team.destroy!
  end
end
