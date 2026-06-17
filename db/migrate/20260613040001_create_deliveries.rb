class CreateDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :deliveries do |t|
      t.references :team, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :error_message
      t.datetime :sent_at

      t.timestamps
    end
    add_index :deliveries, [ :campaign_id, :customer_id ], unique: true
    add_index :deliveries, [ :team_id, :created_at ]
  end
end
