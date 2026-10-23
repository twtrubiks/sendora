# 公開退訂頁:不需登入。GET 顯示確認鈕;POST 執行退訂,
# 同時作為 List-Unsubscribe one-click(RFC 8058)的端點。
# 直接繼承 ActionController::Base:收件人不是 Sendora 的使用者,不套登入與 allow_browser,
# 舊手機的瀏覽器被 406 擋下就退訂不了
class UnsubscribesController < ActionController::Base
  layout "application"
  skip_forgery_protection only: :create
  before_action :set_customer

  def show
  end

  def create
    @customer.unsubscribe!
    render :done
  end

  private
    def set_customer
      @customer = Customer.find_by_token_for(:unsubscribe, params[:token])
      render :invalid, status: :not_found if @customer.nil?
    end
end
