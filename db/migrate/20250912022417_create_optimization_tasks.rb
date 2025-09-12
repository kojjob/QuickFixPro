class CreateOptimizationTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :optimization_tasks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :website_id, null: false
      t.string :fix_type
      t.string :status
      t.jsonb :details, default: {}
      t.text :error_message

      t.timestamps
    end

    add_index :optimization_tasks, :website_id
    add_index :optimization_tasks, :status
    add_index :optimization_tasks, :fix_type
    add_foreign_key :optimization_tasks, :websites
  end
end
