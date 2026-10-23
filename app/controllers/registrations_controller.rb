class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  # 也擋住猜邀請碼
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "操作太頻繁,請稍後再試。" }
  before_action :require_signup_open!

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if !Signup.code_valid?(params[:signup_code])
      flash.now[:alert] = "邀請碼不正確"
      render :new, status: :unprocessable_entity
    elsif @user.save
      start_new_session_for @user
      redirect_to new_team_path, notice: "註冊成功,先建立你的第一個團隊吧!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end

    def require_signup_open!
      return if Signup.open?

      redirect_to new_session_path, alert: "目前不開放註冊,請聯絡系統管理者"
    end
end
