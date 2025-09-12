class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :plan_name, null: false
      t.integer :status, default: 0, null: false
      t.decimal :monthly_price, precision: 8, scale: 2
      t.jsonb :usage_limits, default: {}

      # Additional subscription fields
      t.datetime :trial_ends_at
      t.datetime :billing_cycle_started_at
      t.datetime :cancelled_at
      t.string :external_subscription_id
      t.jsonb :plan_features, default: {}
      t.jsonb :current_usage, default: {}

      t.timestamps
    end

    add_index :subscriptions, :status
    add_index :subscriptions, :plan_name
    add_index :subscriptions, :trial_ends_at
    add_index :subscriptions, :external_subscription_id, unique: true
    add_index :subscriptions, :usage_limits, using: :gin
    add_index :subscriptions, :plan_features, using: :gin
    add_index :subscriptions, :current_usage, using: :gin
  end
end
