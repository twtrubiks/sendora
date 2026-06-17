class TagsController < ApplicationController
  include TeamContext

  def index
    @tags = Current.team.tags.left_joins(:customer_tags).group(:id)
                   .select("tags.*, COUNT(customer_tags.id) AS customers_count").order(:name)
    @tag = Current.team.tags.new
  end

  def create
    @tag = Current.team.tags.new(tag_params)

    if @tag.save
      redirect_to tags_path, notice: "標籤「#{@tag.name}」已建立"
    else
      redirect_to tags_path, alert: @tag.errors.full_messages.to_sentence
    end
  end

  def edit
    @tag = Current.team.tags.find(params[:id])
  end

  def update
    @tag = Current.team.tags.find(params[:id])

    if @tag.update(tag_params)
      redirect_to tags_path, notice: "標籤已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    tag = Current.team.tags.find(params[:id])
    tag.destroy
    redirect_to tags_path, notice: "標籤「#{tag.name}」已刪除", status: :see_other
  end

  private
    def tag_params
      params.expect(tag: [ :name ])
    end
end
