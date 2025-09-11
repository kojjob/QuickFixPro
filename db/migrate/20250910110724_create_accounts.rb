class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts, id: :uuid do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.integer :status, default: 0, null: false
      t.uuid :created_by_id
      t.jsonb :settings, default: {}
      t.text :description

      t.timestamps
    end

    add_index :accounts, :subdomain, unique: true
    add_index :accounts, :status
    add_index :accounts, :created_by_id
    add_index :accounts, :settings, using: :gin
  end
end
