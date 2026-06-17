module TeamContext
  extend ActiveSupport::Concern

  included do
    before_action :set_current_team
  end

  private
    def set_current_team
      # find_by(無 !):團隊不存在、或存在但使用者非成員,都回 nil 走同一條導向,
      # 兩種情況回應完全一致 → 不洩漏團隊是否存在。
      Current.membership = Current.user.memberships.joins(:team).includes(:team)
                                  .find_by(teams: { slug: params[:team_slug] })
      return redirect_to root_path, alert: "找不到團隊,或你沒有存取權限" unless Current.membership

      Current.team = Current.membership.team
    end

    def require_owner!
      unless Current.membership.owner?
        redirect_to team_root_path, alert: "只有團隊擁有者可以執行此操作"
      end
    end

    def default_url_options
      { team_slug: Current.team&.slug }.compact
    end
end
