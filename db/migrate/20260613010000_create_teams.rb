class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :monthly_send_quota, null: false, default: 5000

      t.timestamps
    end
    add_index :teams, :slug, unique: true
  end
end
