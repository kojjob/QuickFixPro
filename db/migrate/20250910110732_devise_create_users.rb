# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Multi-tenant fields
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :first_name
      t.string :last_name
      t.integer :role, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :preferences, default: {}

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, [:account_id, :email], unique: true
    add_index :users, [:account_id, :role]
    add_index :users, :active
    add_index :users, :preferences, using: :gin
  end
end
