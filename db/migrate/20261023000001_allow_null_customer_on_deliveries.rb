class AllowNullCustomerOnDeliveries < ActiveRecord::Migration[8.1]
  # 刪除客戶時保留發送紀錄(本月額度、活動成效不變),只把 customer_id 斷開
  def change
    change_column_null :deliveries, :customer_id, true
  end
end
