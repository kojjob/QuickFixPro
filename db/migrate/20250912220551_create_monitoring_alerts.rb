class CreateMonitoringAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :monitoring_alerts, id: :uuid do |t|
      t.references :website, null: false, foreign_key: true, type: :uuid
      t.integer :alert_type
      t.integer :severity
      t.text :message
      t.decimal :threshold_value
      t.decimal :current_value
      t.boolean :resolved
      t.datetime :resolved_at

      t.timestamps
    end
  end
end
