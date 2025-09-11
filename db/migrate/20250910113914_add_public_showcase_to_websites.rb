class AddPublicShowcaseToWebsites < ActiveRecord::Migration[8.0]
  def change
    add_column :websites, :public_showcase, :boolean, default: false, null: false
    add_index :websites, :public_showcase
  end
end
