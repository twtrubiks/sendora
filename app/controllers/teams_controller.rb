class TeamsController < ApplicationController
  def index
    @memberships = Current.user.memberships.joins(:team).includes(:team).order("teams.name")
    redirect_to new_team_path if @memberships.empty?
  end

  def new
    @team = Team.new
  end

  def create
    @team = Team.new(team_params)

    ApplicationRecord.transaction do
      @team.save!
      @team.memberships.create!(user: Current.user, role: :owner)
    end

    redirect_to team_root_path(team_slug: @team.slug), notice: "團隊「#{@team.name}」已建立"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private
    def team_params
      params.expect(team: [ :name, :slug ])
    end
end
