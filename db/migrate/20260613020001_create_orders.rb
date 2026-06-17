class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :team, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :number, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false, default: 0
      t.datetime :ordered_at, null: false

      t.timestamps
    end
    add_index :orders, [ :team_id, :number ], unique: true
  end
end
