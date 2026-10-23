# 註冊的開關與邀請碼。註冊頁是公開的,沒有門檻的話任何人都能註冊、建團隊、
# 用部署者的 SMTP 與網域寄信,所以 production 一律憑邀請碼(環境變數 SIGNUP_CODE)註冊;
# 沒設就關閉註冊,免得忘了設變成門戶大開。development / test 沒設則開放,本機開發不必多一道手續。
# 邀請碼是一組共用的字串,由團隊擁有者告訴要加入的人;猜碼靠 RegistrationsController 的 rate_limit 擋
module Signup
  # production 沒設邀請碼就關閉註冊;其他環境沒設則開放(測試會改這個值模擬 production)
  mattr_accessor :closed_without_code, default: Rails.env.production?

  def self.code = ENV["SIGNUP_CODE"].presence

  def self.code_required? = code.present?

  def self.open? = code_required? || !closed_without_code

  def self.code_valid?(input)
    return true unless code_required?

    ActiveSupport::SecurityUtils.secure_compare(input.to_s, code)
  end
end
