# 公開退訂頁:不需登入。GET 顯示確認鈕;POST 執行退訂,
# 同時作為 List-Unsubscribe one-click(RFC 8058)的端點。
class UnsubscribesController < ApplicationController
  allow_unauthenticated_access
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
