# 把 Audience 的 conditions(jsonb)轉成 ActiveRecord scope chain。
# 支援的條件(彼此 AND):
#   tags:            ["VIP", ...]   必須擁有列出的每一個標籤
#   min_total_spent: 1000           累計消費 ≥
#   max_total_spent: 5000           累計消費 ≤(沒有訂單視為 0)
#   min_orders_count: 2             訂單數 ≥
#   ordered_after:   "2026-01-01"   最近購買日 ≥
#   ordered_before:  "2026-01-01"   最近購買日 <(從未購買者不符合)
#   created_after / created_before  客戶建立日期
class AudienceQuery
  CONDITION_KEYS = %w[
    tags min_total_spent max_total_spent min_orders_count
    ordered_after ordered_before created_after created_before
  ].freeze

  def initialize(team, conditions = {})
    @team = team
    @conditions = (conditions || {}).stringify_keys
  end

  def customers
    scope = @team.customers
    scope = apply_tags(scope)
    scope = apply_order_stats(scope)
    scope = apply_created_range(scope)
    scope
  end

  def count
    customers.count
  end

  private
    def apply_tags(scope)
      Array(@conditions["tags"]).each do |tag_name|
        tag = @team.tags.find_by(name: tag_name)
        return scope.none if tag.nil?

        scope = scope.where(id: CustomerTag.where(tag_id: tag.id).select(:customer_id))
      end
      scope
    end

    def apply_order_stats(scope)
      grouped = @team.customers.left_joins(:orders).group(:id)
      applied = false

      if (min = decimal_value("min_total_spent"))
        grouped = grouped.having("COALESCE(SUM(orders.amount), 0) >= ?", min)
        applied = true
      end

      if (max = decimal_value("max_total_spent"))
        grouped = grouped.having("COALESCE(SUM(orders.amount), 0) <= ?", max)
        applied = true
      end

      if (min_count = integer_value("min_orders_count"))
        grouped = grouped.having("COUNT(orders.id) >= ?", min_count)
        applied = true
      end

      if (date = date_value("ordered_after"))
        grouped = grouped.having("MAX(orders.ordered_at) >= ?", date.beginning_of_day)
        applied = true
      end

      if (date = date_value("ordered_before"))
        grouped = grouped.having("MAX(orders.ordered_at) < ?", date.beginning_of_day)
        applied = true
      end

      applied ? scope.where(id: grouped.select(:id)) : scope
    end

    def apply_created_range(scope)
      if (date = date_value("created_after"))
        scope = scope.where(created_at: date.beginning_of_day..)
      end

      if (date = date_value("created_before"))
        scope = scope.where(created_at: ...date.beginning_of_day)
      end

      scope
    end

    def decimal_value(key)
      value = @conditions[key]
      return nil if value.blank?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def integer_value(key)
      value = @conditions[key]
      return nil if value.blank?

      Integer(value.to_s, exception: false)
    end

    def date_value(key)
      value = @conditions[key]
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
end
