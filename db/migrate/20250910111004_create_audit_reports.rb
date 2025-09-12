class CreateAuditReports < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_reports, id: :uuid do |t|
      t.references :website, null: false, foreign_key: true, type: :uuid
      t.references :triggered_by, null: true, foreign_key: { to_table: :users }, type: :uuid
      t.integer :overall_score
      t.integer :audit_type, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.decimal :duration, precision: 8, scale: 3

      # Additional audit fields
      t.text :error_message
      t.jsonb :raw_results, default: {}
      t.jsonb :summary_data, default: {}
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :audit_reports, [ :website_id, :status ]
    add_index :audit_reports, [ :website_id, :created_at ]
    add_index :audit_reports, :overall_score
    add_index :audit_reports, :audit_type
    add_index :audit_reports, :status
    add_index :audit_reports, :raw_results, using: :gin
    add_index :audit_reports, :summary_data, using: :gin
  end
end
