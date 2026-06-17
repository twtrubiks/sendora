class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.references :team, null: false, foreign_key: true
      t.references :audience, null: false, foreign_key: true
      t.string :name, null: false
      t.string :subject, null: false
      t.text :body, null: false
      t.integer :status, null: false, default: 0
      t.string :error_message
      t.datetime :sent_at

      t.timestamps
    end
  end
end
