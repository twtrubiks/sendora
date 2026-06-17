class CreateImportJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :import_jobs do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :filename, null: false
      t.integer :total_rows, null: false, default: 0
      t.integer :success_count, null: false, default: 0
      t.integer :failure_count, null: false, default: 0
      t.string :error_message

      t.timestamps
    end
  end
end
