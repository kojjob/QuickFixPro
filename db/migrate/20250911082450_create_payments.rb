class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments, id: :uuid do |t|
      t.references :subscription, null: false, foreign_key: true, type: :uuid
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, null: false, default: 'pending'
      t.string :payment_method, null: false
      t.string :stripe_payment_intent_id
      t.string :stripe_charge_id
      t.decimal :tax_rate, precision: 5, scale: 4, default: 0.0
      t.datetime :refunded_at
      t.datetime :failed_at
      t.text :failure_reason
      t.string :invoice_number
      t.integer :retry_count, default: 0
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :payments, :status
    add_index :payments, :stripe_payment_intent_id, unique: true
    add_index :payments, :invoice_number, unique: true
    add_index :payments, :created_at
  end
end
