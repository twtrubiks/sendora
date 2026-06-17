require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "同團隊標籤名稱不可重複" do
    tag = teams(:acme).tags.new(name: " VIP ")
    assert_not tag.valid?
    assert tag.errors[:name].any?
  end

  test "不同團隊可以有同名標籤" do
    assert tags(:acme_vip).valid?
    assert tags(:globex_vip).valid?
  end

  test "同客戶不可重複貼同一個標籤" do
    duplicate = CustomerTag.new(customer: customers(:acme_tom), tag: tags(:acme_vip))
    assert_not duplicate.valid?
  end

  test "刪除標籤會一併撕下客戶身上的標籤" do
    assert_difference "CustomerTag.count", -1 do
      tags(:acme_vip).destroy
    end
  end
end
