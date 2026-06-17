class Settings::TeamsController < ApplicationController
  include TeamContext
  before_action :require_owner!, only: :destroy

  def show
    @team = Current.team
  end

  def update
    @team = Current.team

    if @team.update(team_params)
      redirect_to settings_team_path, notice: "團隊名稱已更新"
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @team = Current.team

    if params[:confirm_slug] != @team.slug
      redirect_to settings_team_path, alert: "輸入的網址代稱不符,團隊未刪除"
    else
      @team.destroy
      redirect_to teams_path(team_slug: nil), notice: "團隊「#{@team.name}」已刪除"
    end
  end

  private
    def team_params
      params.expect(team: [ :name ])
    end
end
