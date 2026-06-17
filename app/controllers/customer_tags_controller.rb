class CustomerTagsController < ApplicationController
  include TeamContext
  before_action :set_customer

  def create
    tag = Current.team.tags.find(params[:tag_id])
    @customer.customer_tags.find_or_create_by!(tag: tag)
    redirect_to customer_path(@customer), notice: "已貼上標籤「#{tag.name}」"
  end

  def destroy
    tag = Current.team.tags.find(params[:id])
    @customer.customer_tags.find_by!(tag: tag).destroy
    redirect_to customer_path(@customer), notice: "已移除標籤「#{tag.name}」", status: :see_other
  end

  private
    def set_customer
      @customer = Current.team.customers.find(params[:customer_id])
    end
end
