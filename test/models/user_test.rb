require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "email 格式不正確時無效" do
    user = User.new(email_address: "not-an-email", password: "password")
    assert_not user.valid?
    assert user.errors[:email_address].any?
  end

  test "email 不可重複" do
    user = User.new(email_address: "ALICE@example.com", password: "password")
    assert_not user.valid?
    assert user.errors[:email_address].any?
  end

  test "密碼至少 8 個字元" do
    user = User.new(email_address: "short@example.com", password: "1234567")
    assert_not user.valid?
    assert user.errors[:password].any?
  end
end
