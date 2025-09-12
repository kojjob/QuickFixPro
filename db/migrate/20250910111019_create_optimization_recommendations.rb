class CreateOptimizationRecommendations < ActiveRecord::Migration[8.0]
  def change
    create_table :optimization_recommendations, id: :uuid do |t|
      t.references :audit_report, null: false, foreign_key: true, type: :uuid
      t.references :website, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :description, null: false
      t.integer :priority, default: 0, null: false
      t.string :estimated_savings
      t.integer :status, default: 0, null: false

      # Additional recommendation fields
      t.string :category
      t.text :implementation_guide
      t.string :difficulty_level, default: 'medium'
      t.decimal :potential_score_improvement, precision: 5, scale: 2
      t.jsonb :resources, default: []
      t.boolean :automated_fix_available, default: false

      t.timestamps
    end

    add_index :optimization_recommendations, [ :website_id, :priority ]
    add_index :optimization_recommendations, [ :website_id, :status ]
    add_index :optimization_recommendations, :priority
    add_index :optimization_recommendations, :status
    add_index :optimization_recommendations, :category
    add_index :optimization_recommendations, :resources, using: :gin
  end
end
