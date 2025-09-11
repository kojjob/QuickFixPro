class CreateMonitoringAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :monitoring_alerts, id: :uuid do |t|
      t.references :website, null: false, foreign_key: true, type: :uuid
      t.string :alert_type
      t.string :severity
      t.text :message
      t.boolean :resolved, default: false
      t.datetime :resolved_at
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :monitoring_alerts, [:website_id, :created_at]
    add_index :monitoring_alerts, [:resolved, :severity]
  end
end
