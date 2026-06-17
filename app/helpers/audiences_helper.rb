module AudiencesHelper
  CONDITION_LABELS = {
    "tag" => "擁有標籤",
    "min_total_spent" => "累計消費 ≥",
    "max_total_spent" => "累計消費 ≤",
    "min_orders_count" => "訂單數 ≥",
    "ordered_after" => "最近購買日 ≥",
    "ordered_before" => "最近購買日早於",
    "created_after" => "建立日期 ≥",
    "created_before" => "建立日期早於"
  }.freeze

  def condition_key_options
    CONDITION_LABELS.map { |key, label| [ label, key ] }
  end

  def condition_value_type(key)
    return "tag" if key == "tag"
    return "date" if key.end_with?("_after", "_before")

    "number"
  end

  # 把扁平的 conditions 展開成表單用的 [key, value] 條件列
  def audience_condition_rows(audience)
    rows = Array(audience.conditions["tags"]).map { |tag_name| [ "tag", tag_name ] }

    (AudienceQuery::CONDITION_KEYS - [ "tags" ]).each do |key|
      rows << [ key, audience.conditions[key] ] if audience.conditions[key].present?
    end

    rows
  end

  def audience_conditions_summary(audience)
    parts = audience_condition_rows(audience).map do |key, value|
      key == "tag" ? "擁有標籤「#{value}」" : "#{CONDITION_LABELS[key]} #{value}"
    end

    parts.empty? ? "全部客戶" : parts.join("、")
  end
end
