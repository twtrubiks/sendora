class CreateCustomerTags < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_tags do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :customer_tags, [ :customer_id, :tag_id ], unique: true
  end
end
