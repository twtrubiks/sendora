class CustomersController < ApplicationController
  include TeamContext
  before_action :set_customer, only: %i[ show edit update destroy ]

  def index
    scope = Current.team.customers.search(params[:q]).order(created_at: :desc)

    respond_to do |format|
      format.html { @pagy, @customers = pagy(scope) }
      format.csv { stream_customers_csv(scope) }
    end
  end

  def show
    @orders = @customer.orders.order(ordered_at: :desc)
    @total_spent = @orders.sum(:amount)
  end

  def new
    @customer = Current.team.customers.new
  end

  def create
    @customer = Current.team.customers.new(customer_params)

    if @customer.save
      redirect_to customer_path(@customer), notice: "客戶已新增"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to customer_path(@customer), notice: "客戶資料已更新"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: "客戶已刪除", status: :see_other
  end

  private
    def set_customer
      @customer = Current.team.customers.find(params[:id])
    end

    def customer_params
      params.expect(customer: [ :email, :name, :phone ])
    end

    def stream_customers_csv(scope)
      response.headers["Content-Type"] = "text/csv; charset=utf-8"
      response.headers["Content-Disposition"] = %(attachment; filename="customers.csv")
      customers = scope.reorder(:id).includes(:tags)
      self.response_body = Enumerator.new do |yielder|
        yielder << CSV.generate_line([ "email", "name", "phone", "tags", "unsubscribed_at", "bounced_at", "created_at" ])
        customers.find_each do |customer|
          yielder << CSV.generate_line([
            customer.email, customer.name, customer.phone,
            customer.tags.map(&:name).join("|"),
            customer.unsubscribed_at&.strftime("%Y-%m-%d"),
            customer.bounced_at&.strftime("%Y-%m-%d"),
            customer.created_at.strftime("%Y-%m-%d")
          ])
        end
      end
    end
end
