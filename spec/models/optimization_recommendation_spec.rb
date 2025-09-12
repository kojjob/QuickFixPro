require 'rails_helper'

RSpec.describe OptimizationRecommendation, type: :model do
  let(:audit_report) { create(:audit_report) }
  let(:website) { create(:website) }
  let(:recommendation) { create(:optimization_recommendation, audit_report: audit_report, website: website) }
  
  describe 'associations' do
    it { should belong_to(:audit_report) }
    it { should belong_to(:website) }
  end
  
  describe 'validations' do
    describe 'title' do
      it { should validate_presence_of(:title) }
      it { should validate_length_of(:title).is_at_most(200) }
      
      it 'accepts valid titles' do
        recommendation = build(:optimization_recommendation, title: 'Optimize Images')
        expect(recommendation).to be_valid
      end
      
      it 'rejects overly long titles' do
        recommendation = build(:optimization_recommendation, title: 'a' * 201)
        expect(recommendation).not_to be_valid
        expect(recommendation.errors[:title]).to include('is too long (maximum is 200 characters)')
      end
    end
    
    describe 'description' do
      it { should validate_presence_of(:description) }
    end
    
    describe 'priority' do
      it { should validate_presence_of(:priority) }
    end
    
    describe 'status' do
      it { should validate_presence_of(:status) }
    end
    
    describe 'difficulty_level' do
      it { should validate_inclusion_of(:difficulty_level).in_array(%w[easy medium hard expert]) }
      
      it 'accepts valid difficulty levels' do
        %w[easy medium hard expert].each do |level|
          recommendation = build(:optimization_recommendation, difficulty_level: level)
          expect(recommendation).to be_valid
        end
      end
      
      it 'rejects invalid difficulty levels' do
        recommendation = build(:optimization_recommendation, difficulty_level: 'impossible')
        expect(recommendation).not_to be_valid
        expect(recommendation.errors[:difficulty_level]).to include('is not included in the list')
      end
    end
  end
  
  describe 'enums' do
    describe 'priority' do
      it { should define_enum_for(:priority).with_values(low: 0, medium: 1, high: 2, critical: 3) }
      
      it 'can be set to different priorities' do
        expect(build(:optimization_recommendation, priority: :low)).to be_low
        expect(build(:optimization_recommendation, priority: :medium)).to be_medium
        expect(build(:optimization_recommendation, priority: :high)).to be_high
        expect(build(:optimization_recommendation, priority: :critical)).to be_critical
      end
    end
    
    describe 'status' do
      it { should define_enum_for(:status).with_values(pending: 0, in_progress: 1, completed: 2, dismissed: 3) }
      
      it 'can be set to different statuses' do
        expect(build(:optimization_recommendation, status: :pending)).to be_pending
        expect(build(:optimization_recommendation, status: :in_progress)).to be_in_progress
        expect(build(:optimization_recommendation, status: :completed)).to be_completed
        expect(build(:optimization_recommendation, status: :dismissed)).to be_dismissed
      end
    end
  end
  
  describe 'scopes' do
    describe '.by_priority' do
      let!(:low_priority) { create(:optimization_recommendation, :low) }
      let!(:high_priority) { create(:optimization_recommendation, :high) }
      let!(:critical_priority) { create(:optimization_recommendation, :critical) }
      
      it 'returns recommendations with specified priority' do
        expect(OptimizationRecommendation.by_priority(:high)).to include(high_priority)
        expect(OptimizationRecommendation.by_priority(:high)).not_to include(low_priority, critical_priority)
      end
    end
    
    describe '.actionable' do
      let!(:pending) { create(:optimization_recommendation, status: :pending) }
      let!(:in_progress) { create(:optimization_recommendation, status: :in_progress) }
      let!(:completed) { create(:optimization_recommendation, status: :completed) }
      let!(:dismissed) { create(:optimization_recommendation, status: :dismissed) }
      
      it 'returns only pending and in_progress recommendations' do
        expect(OptimizationRecommendation.actionable).to include(pending, in_progress)
        expect(OptimizationRecommendation.actionable).not_to include(completed, dismissed)
      end
    end
    
    describe '.high_impact' do
      let!(:low) { create(:optimization_recommendation, priority: :low) }
      let!(:medium) { create(:optimization_recommendation, priority: :medium) }
      let!(:high) { create(:optimization_recommendation, priority: :high) }
      let!(:critical) { create(:optimization_recommendation, priority: :critical) }
      
      it 'returns only high and critical priority recommendations' do
        expect(OptimizationRecommendation.high_impact).to include(high, critical)
        expect(OptimizationRecommendation.high_impact).not_to include(low, medium)
      end
    end
    
    describe '.by_category' do
      let!(:images_rec) { create(:optimization_recommendation, category: 'images') }
      let!(:javascript_rec) { create(:optimization_recommendation, category: 'javascript') }
      let!(:css_rec) { create(:optimization_recommendation, category: 'css') }
      
      it 'returns recommendations for specified category' do
        expect(OptimizationRecommendation.by_category('images')).to include(images_rec)
        expect(OptimizationRecommendation.by_category('images')).not_to include(javascript_rec, css_rec)
      end
    end
  end
  
  describe 'instance methods' do
    describe '#priority_color' do
      it 'returns correct color for each priority level' do
        expect(build(:optimization_recommendation, priority: :critical).priority_color).to eq('red')
        expect(build(:optimization_recommendation, priority: :high).priority_color).to eq('orange')
        expect(build(:optimization_recommendation, priority: :medium).priority_color).to eq('yellow')
        expect(build(:optimization_recommendation, priority: :low).priority_color).to eq('blue')
      end
    end
    
    describe '#difficulty_badge_color' do
      it 'returns correct color for each difficulty level' do
        expect(build(:optimization_recommendation, difficulty_level: 'easy').difficulty_badge_color).to eq('green')
        expect(build(:optimization_recommendation, difficulty_level: 'medium').difficulty_badge_color).to eq('yellow')
        expect(build(:optimization_recommendation, difficulty_level: 'hard').difficulty_badge_color).to eq('orange')
        expect(build(:optimization_recommendation, difficulty_level: 'expert').difficulty_badge_color).to eq('red')
      end
      
      it 'returns gray for invalid difficulty level' do
        recommendation = build(:optimization_recommendation)
        recommendation.difficulty_level = 'invalid'
        expect(recommendation.difficulty_badge_color).to eq('gray')
      end
    end
    
    describe '#estimated_impact' do
      it 'returns high impact for improvement >= 10 points' do
        recommendation = build(:optimization_recommendation, potential_score_improvement: 15)
        expect(recommendation.estimated_impact).to eq('High Impact (+15.0 points)')
      end
      
      it 'returns medium impact for improvement >= 5 and < 10 points' do
        recommendation = build(:optimization_recommendation, potential_score_improvement: 7)
        expect(recommendation.estimated_impact).to eq('Medium Impact (+7.0 points)')
      end
      
      it 'returns low impact for improvement < 5 points' do
        recommendation = build(:optimization_recommendation, potential_score_improvement: 3)
        expect(recommendation.estimated_impact).to eq('Low Impact (+3.0 points)')
      end
      
      it 'returns Unknown when potential_score_improvement is nil' do
        recommendation = build(:optimization_recommendation, potential_score_improvement: nil)
        expect(recommendation.estimated_impact).to eq('Unknown')
      end
    end
    
    describe '#can_implement_automatically?' do
      it 'returns true when automated fix is available and difficulty is easy' do
        recommendation = build(:optimization_recommendation, 
                             automated_fix_available: true, 
                             difficulty_level: 'easy')
        expect(recommendation.can_implement_automatically?).to be true
      end
      
      it 'returns false when automated fix is not available' do
        recommendation = build(:optimization_recommendation, 
                             automated_fix_available: false, 
                             difficulty_level: 'easy')
        expect(recommendation.can_implement_automatically?).to be false
      end
      
      it 'returns false when difficulty is not easy' do
        recommendation = build(:optimization_recommendation, 
                             automated_fix_available: true, 
                             difficulty_level: 'medium')
        expect(recommendation.can_implement_automatically?).to be false
      end
    end
    
    describe '#resources_list' do
      it 'returns array when resources is an array' do
        resources = ['https://example.com', 'https://example.org']
        recommendation = build(:optimization_recommendation, resources: resources)
        expect(recommendation.resources_list).to eq(resources)
      end
      
      it 'returns empty array when resources is not an array' do
        recommendation = build(:optimization_recommendation, resources: 'not an array')
        expect(recommendation.resources_list).to eq([])
      end
      
      it 'returns empty array when resources is nil' do
        recommendation = build(:optimization_recommendation, resources: nil)
        expect(recommendation.resources_list).to eq([])
      end
    end
    
    describe '#mark_as_completed!' do
      it 'updates status to completed' do
        recommendation = create(:optimization_recommendation, status: :pending)
        recommendation.mark_as_completed!
        expect(recommendation.reload.status).to eq('completed')
      end
    end
    
    describe '#mark_as_dismissed!' do
      it 'updates status to dismissed' do
        recommendation = create(:optimization_recommendation, status: :pending)
        recommendation.mark_as_dismissed!('Not applicable')
        expect(recommendation.reload.status).to eq('dismissed')
      end
    end
    
    describe '#mark_in_progress!' do
      it 'updates status to in_progress' do
        recommendation = create(:optimization_recommendation, status: :pending)
        recommendation.mark_in_progress!
        expect(recommendation.reload.status).to eq('in_progress')
      end
    end
  end
  
  describe 'class methods' do
    describe '.categories' do
      it 'returns expected category list' do
        expected_categories = %w[
          images
          javascript
          css
          caching
          server_configuration
          third_party
          accessibility
          seo
          mobile
          security
        ]
        expect(OptimizationRecommendation.categories).to eq(expected_categories)
      end
    end
    
    describe '.create_image_optimization_recommendation' do
      let(:audit_report) { create(:audit_report) }
      
      it 'creates an image optimization recommendation with correct attributes' do
        recommendation = OptimizationRecommendation.create_image_optimization_recommendation(
          audit_report, 
          '2.5 seconds'
        )
        
        expect(recommendation).to be_persisted
        expect(recommendation.audit_report).to eq(audit_report)
        expect(recommendation.website).to eq(audit_report.website)
        expect(recommendation.title).to eq('Optimize Images')
        expect(recommendation.category).to eq('images')
        expect(recommendation.priority).to eq('high')
        expect(recommendation.difficulty_level).to eq('medium')
        expect(recommendation.estimated_savings).to eq('2.5 seconds')
        expect(recommendation.potential_score_improvement).to eq(15)
        expect(recommendation.implementation_guide).to include('Compress large images')
        expect(recommendation.resources).to be_an(Array)
        expect(recommendation.resources).to include('https://web.dev/optimize-images/')
      end
    end
    
    describe '.create_javascript_optimization_recommendation' do
      let(:audit_report) { create(:audit_report) }
      
      it 'creates a JavaScript optimization recommendation with correct attributes' do
        recommendation = OptimizationRecommendation.create_javascript_optimization_recommendation(
          audit_report, 
          '1.8 seconds'
        )
        
        expect(recommendation).to be_persisted
        expect(recommendation.audit_report).to eq(audit_report)
        expect(recommendation.website).to eq(audit_report.website)
        expect(recommendation.title).to eq('Optimize JavaScript Delivery')
        expect(recommendation.category).to eq('javascript')
        expect(recommendation.priority).to eq('high')
        expect(recommendation.difficulty_level).to eq('hard')
        expect(recommendation.estimated_savings).to eq('1.8 seconds')
        expect(recommendation.potential_score_improvement).to eq(20)
        expect(recommendation.implementation_guide).to include('Minify JavaScript files')
        expect(recommendation.resources).to be_an(Array)
        expect(recommendation.resources).to include('https://web.dev/reduce-unused-javascript/')
      end
    end
  end
  
  describe 'database columns' do
    it { should have_db_column(:audit_report_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:website_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:title).of_type(:string) }
    it { should have_db_column(:description).of_type(:text) }
    it { should have_db_column(:category).of_type(:string) }
    it { should have_db_column(:priority).of_type(:integer) }
    it { should have_db_column(:status).of_type(:integer).with_options(default: 'pending') }
    it { should have_db_column(:difficulty_level).of_type(:string) }
    it { should have_db_column(:estimated_savings).of_type(:string) }
    it { should have_db_column(:potential_score_improvement).of_type(:decimal) }
    it { should have_db_column(:automated_fix_available).of_type(:boolean).with_options(default: false) }
    it { should have_db_column(:implementation_guide).of_type(:text) }
    it { should have_db_column(:resources).of_type(:jsonb) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
  end
  
  describe 'database indexes' do
    it { should have_db_index(:audit_report_id) }
    it { should have_db_index(:website_id) }
    it { should have_db_index(:priority) }
    it { should have_db_index(:status) }
    it { should have_db_index(:category) }
  end
end