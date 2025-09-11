class CreateWebsites < ActiveRecord::Migration[8.0]
  def change
    create_table :websites, id: :uuid do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.integer :status, default: 0, null: false
      t.integer :monitoring_frequency, default: 0, null: false
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid
      
      # Additional monitoring fields
      t.text :description
      t.jsonb :monitoring_settings, default: {}
      t.datetime :last_monitored_at
      t.integer :current_score
      t.boolean :alerts_enabled, default: true
      t.jsonb :notification_settings, default: {}

      t.timestamps
    end

    add_index :websites, [:account_id, :status]
    add_index :websites, [:account_id, :name]
    add_index :websites, :last_monitored_at
    add_index :websites, :monitoring_frequency
    add_index :websites, :monitoring_settings, using: :gin
    add_index :websites, :notification_settings, using: :gin
    add_index :websites, [:account_id, :url], unique: true
  end
end
