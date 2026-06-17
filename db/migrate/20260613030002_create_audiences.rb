class CreateAudiences < ActiveRecord::Migration[8.1]
  def change
    create_table :audiences do |t|
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :conditions, null: false, default: {}

      t.timestamps
    end
  end
end
