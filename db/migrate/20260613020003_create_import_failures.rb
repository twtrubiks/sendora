class CreateImportFailures < ActiveRecord::Migration[8.1]
  def change
    create_table :import_failures do |t|
      t.references :import_job, null: false, foreign_key: true
      t.integer :line_number, null: false
      t.string :message, null: false
      t.text :raw_row

      t.timestamps
    end
  end
end
