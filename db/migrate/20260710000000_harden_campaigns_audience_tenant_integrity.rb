class HardenCampaignsAudienceTenantIntegrity < ActiveRecord::Migration[8.1]
  def up
    # Model validation 不回溯:若漏洞存活期間已綁定跨團隊分群,先擋下來人工處理,
    # 否則底下的複合外鍵會直接失敗、錯誤訊息也難以理解
    offending = select_values(<<~SQL)
      SELECT campaigns.id
      FROM campaigns
      JOIN audiences ON audiences.id = campaigns.audience_id
      WHERE campaigns.team_id != audiences.team_id
    SQL
    if offending.any?
      raise "campaigns(id: #{offending.join(', ')}) 綁定了別團隊的分群,請先人工改綁或刪除再重跑 migration"
    end

    # 讓 (id, team_id) 可被複合外鍵參照
    add_index :audiences, [ :id, :team_id ], unique: true

    # 以複合外鍵取代單欄外鍵:跨團隊綁定在 DB 層直接不可能,
    # save(validate: false) / update_column / insert_all 等繞過 validation 的路徑也擋得住
    remove_foreign_key :campaigns, :audiences
    add_foreign_key :campaigns, :audiences,
                    column: [ :audience_id, :team_id ], primary_key: [ :id, :team_id ]
  end

  def down
    remove_foreign_key :campaigns, :audiences, column: [ :audience_id, :team_id ]
    add_foreign_key :campaigns, :audiences
    remove_index :audiences, column: [ :id, :team_id ]
  end
end
