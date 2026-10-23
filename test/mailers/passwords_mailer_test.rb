require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:alice)
    @mail = PasswordsMailer.reset(@user)
  end

  test "寄給申請的使用者,主旨為重設密碼" do
    assert_equal [ "alice@example.com" ], @mail.to
    assert_equal "重設你的 Sendora 密碼", @mail.subject
  end

  test "純文字與 HTML 版都帶可用的重設連結" do
    [ @mail.text_part, @mail.html_part ].each do |part|
      token = part.body.to_s[%r{/passwords/([^/\s"]+)/edit}, 1]
      assert_equal @user, User.find_by_password_reset_token!(token), part.content_type
    end
  end
end
