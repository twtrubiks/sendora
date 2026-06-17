class DashboardsController < ApplicationController
  include TeamContext

  PERIODS = %w[ this_month last_month last_30_days ].freeze

  def show
    @has_data = Current.team.customers.exists?
    return unless @has_data

    @period = PERIODS.include?(params[:period]) ? params[:period] : "this_month"
    @range, @previous_range = ranges_for(@period)

    orders = Current.team.orders
    customers = Current.team.customers

    @kpis = {
      revenue: [ orders.where(ordered_at: @range).sum(:amount),
                 orders.where(ordered_at: @previous_range).sum(:amount) ],
      orders_count: [ orders.where(ordered_at: @range).count,
                      orders.where(ordered_at: @previous_range).count ],
      new_customers: [ customers.where(created_at: @range).count,
                       customers.where(created_at: @previous_range).count ],
      active_customers: [ orders.where(ordered_at: @range).distinct.count(:customer_id),
                          orders.where(ordered_at: @previous_range).distinct.count(:customer_id) ]
    }

    @revenue_by_day = orders.where(ordered_at: @range).group_by_day(:ordered_at).sum(:amount)
    @orders_by_day = orders.where(ordered_at: @range).group_by_day(:ordered_at).count

    @recent_campaigns = Current.team.campaigns.where.not(status: :draft)
                               .includes(:audience).order(created_at: :desc).limit(5)
  end

  private
    def ranges_for(period)
      case period
      when "last_month"
        [ 1.month.ago.all_month, 2.months.ago.all_month ]
      when "last_30_days"
        now = Time.current
        [ 30.days.ago.beginning_of_day..now, 60.days.ago.beginning_of_day...30.days.ago.beginning_of_day ]
      else
        [ Time.current.all_month, 1.month.ago.all_month ]
      end
    end
end
