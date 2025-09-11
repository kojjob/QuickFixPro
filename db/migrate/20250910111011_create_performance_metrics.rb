class CreatePerformanceMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :performance_metrics, id: :uuid do |t|
      t.references :audit_report, null: false, foreign_key: true, type: :uuid
      t.references :website, null: false, foreign_key: true, type: :uuid
      t.string :metric_type, null: false
      t.decimal :value, precision: 10, scale: 3, null: false
      t.string :unit, default: 'ms'
      t.integer :threshold_status, default: 0, null: false
      
      # Additional metric fields  
      t.decimal :threshold_good, precision: 10, scale: 3
      t.decimal :threshold_poor, precision: 10, scale: 3
      t.integer :score_contribution
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :performance_metrics, [:website_id, :metric_type]
    add_index :performance_metrics, [:website_id, :created_at]
    add_index :performance_metrics, :metric_type
    add_index :performance_metrics, :threshold_status
    add_index :performance_metrics, :metadata, using: :gin
  end
end
