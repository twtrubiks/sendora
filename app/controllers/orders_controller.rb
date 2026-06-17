class OrdersController < ApplicationController
  include TeamContext
  before_action :set_customer

  def create
    @order = @customer.orders.new(order_params.merge(team: Current.team))

    if @order.save
      redirect_to customer_path(@customer), notice: "訂單已新增"
    else
      redirect_to customer_path(@customer), alert: @order.errors.full_messages.to_sentence
    end
  end

  def destroy
    order = @customer.orders.find(params[:id])
    order.destroy
    redirect_to customer_path(@customer), notice: "訂單已刪除", status: :see_other
  end

  private
    def set_customer
      @customer = Current.team.customers.find(params[:customer_id])
    end

    def order_params
      params.expect(order: [ :number, :amount, :ordered_at ])
    end
end
