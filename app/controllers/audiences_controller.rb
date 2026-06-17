class AudiencesController < ApplicationController
  include TeamContext
  before_action :set_audience, only: %i[ edit update destroy ]

  def index
    @audiences = Current.team.audiences.order(:name)
  end

  def new
    @audience = Current.team.audiences.new
  end

  def create
    @audience = Current.team.audiences.new(name: audience_params[:name], conditions: conditions_from_rows)

    if @audience.save
      redirect_to audiences_path, notice: "分群「#{@audience.name}」已建立"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @audience.update(name: audience_params[:name], conditions: conditions_from_rows)
      redirect_to audiences_path, notice: "分群「#{@audience.name}」已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @audience.destroy
      redirect_to audiences_path, notice: "分群「#{@audience.name}」已刪除", status: :see_other
    else
      redirect_to audiences_path, alert: @audience.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def preview
    @count = AudienceQuery.new(Current.team, conditions_from_rows).count
  end

  private
    def set_audience
      @audience = Current.team.audiences.find(params[:id])
    end

    def audience_params
      params.fetch(:audience, {}).permit(:name, rows: [ :key, :value ])
    end

    # 表單的條件列(key + value)轉成扁平的 conditions jsonb,
    # tags 累加成陣列,其餘鍵重複時以後面的列為準
    def conditions_from_rows
      conditions = {}

      Array(audience_params[:rows]).each do |row|
        key = row[:key].to_s
        value = row[:value].to_s.strip
        next if value.blank?

        case key
        when "tag"
          (conditions["tags"] ||= []) << value unless Array(conditions["tags"]).include?(value)
        when *(AudienceQuery::CONDITION_KEYS - [ "tags" ])
          conditions[key] = value
        end
      end

      conditions
    end
end
