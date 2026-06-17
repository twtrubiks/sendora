class Settings::MembershipsController < ApplicationController
  include TeamContext
  before_action :require_owner!

  def index
    @memberships = Current.team.memberships.includes(:user).order(:created_at)
  end

  def create
    email = params[:email_address].to_s.strip.downcase
    user = User.find_by(email_address: email)

    if user.nil?
      redirect_to settings_memberships_path, alert: "找不到使用 #{email} 的帳號,請先請對方完成註冊"
      return
    end

    membership = Current.team.memberships.new(user: user, role: :member)

    if membership.save
      redirect_to settings_memberships_path, notice: "已將 #{email} 加入團隊"
    else
      redirect_to settings_memberships_path, alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    membership = Current.team.memberships.find(params[:id])

    if membership.owner? && Current.team.memberships.owner.count <= 1
      redirect_to settings_memberships_path, alert: "無法移除最後一位擁有者"
    elsif membership.user == Current.user
      membership.destroy
      redirect_to teams_path(team_slug: nil), notice: "你已離開團隊「#{Current.team.name}」"
    else
      membership.destroy
      redirect_to settings_memberships_path, notice: "已移除成員 #{membership.user.email_address}"
    end
  end
end
