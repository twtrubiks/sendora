class ApplicationMailer < ActionMailer::Base
  # 寄件人要用通過 SPF / DKIM 驗證的網域,正式環境由 MAILER_FROM 指定
  default from: ENV.fetch("MAILER_FROM", "from@example.com")
  layout "mailer"
end
