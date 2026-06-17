class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :team, null: false, foreign_key: true
      t.string :email, null: false
      t.string :name
      t.string :phone
      t.datetime :unsubscribed_at
      t.datetime :bounced_at

      t.timestamps
    end
    add_index :customers, [ :team_id, :email ], unique: true
  end
end
