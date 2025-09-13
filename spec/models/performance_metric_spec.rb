require 'rails_helper'

RSpec.describe PerformanceMetric, type: :model do
  let(:audit_report) { create(:audit_report) }
  let(:website) { create(:website) }
  let(:performance_metric) { create(:performance_metric, audit_report: audit_report, website: website) }
  
  describe 'associations' do
    it { should belong_to(:audit_report) }
    it { should belong_to(:website) }
  end
  
  describe 'validations' do
    describe 'metric_type' do
      it { should validate_presence_of(:metric_type) }
      
      it 'accepts valid metric types' do
        %w[lcp fid cls ttfb fcp speed_index total_blocking_time].each do |type|
          metric = build(:performance_metric, metric_type: type)
          expect(metric).to be_valid
        end
      end
      
      it 'rejects invalid metric types' do
        metric = build(:performance_metric, metric_type: 'invalid_type')
        expect(metric).not_to be_valid
        expect(metric.errors[:metric_type]).to include('must be a valid metric type')
      end
    end
    
    describe 'value' do
      it { should validate_presence_of(:value) }
      it { should validate_numericality_of(:value).is_greater_than_or_equal_to(0) }
      
      it 'accepts zero values' do
        metric = build(:performance_metric, value: 0)
        expect(metric).to be_valid
      end
      
      it 'rejects negative values' do
        metric = build(:performance_metric, value: -1)
        expect(metric).not_to be_valid
        expect(metric.errors[:value]).to be_present
      end
    end
    
    describe 'threshold_status' do
      it { should validate_presence_of(:threshold_status) }
    end
  end
  
  describe 'enums' do
    it { should define_enum_for(:threshold_status).with_values(good: 0, needs_improvement: 1, poor: 2) }
    
    it 'can be set to different statuses' do
      expect(build(:performance_metric, threshold_status: :good)).to be_good
      expect(build(:performance_metric, threshold_status: :needs_improvement)).to be_needs_improvement
      expect(build(:performance_metric, threshold_status: :poor)).to be_poor
    end
  end
  
  describe 'constants' do
    describe 'THRESHOLDS' do
      it 'defines thresholds for all metric types' do
        expect(PerformanceMetric::THRESHOLDS).to have_key('lcp')
        expect(PerformanceMetric::THRESHOLDS).to have_key('fid')
        expect(PerformanceMetric::THRESHOLDS).to have_key('cls')
        expect(PerformanceMetric::THRESHOLDS).to have_key('ttfb')
        expect(PerformanceMetric::THRESHOLDS).to have_key('fcp')
        expect(PerformanceMetric::THRESHOLDS).to have_key('speed_index')
        expect(PerformanceMetric::THRESHOLDS).to have_key('total_blocking_time')
      end
      
      it 'defines correct LCP thresholds' do
        lcp = PerformanceMetric::THRESHOLDS['lcp']
        expect(lcp[:good]).to eq(2500)
        expect(lcp[:poor]).to eq(4000)
        expect(lcp[:unit]).to eq('ms')
        expect(lcp[:name]).to eq('Largest Contentful Paint')
      end
      
      it 'defines correct FID thresholds' do
        fid = PerformanceMetric::THRESHOLDS['fid']
        expect(fid[:good]).to eq(100)
        expect(fid[:poor]).to eq(300)
        expect(fid[:unit]).to eq('ms')
        expect(fid[:name]).to eq('First Input Delay')
      end
      
      it 'defines correct CLS thresholds' do
        cls = PerformanceMetric::THRESHOLDS['cls']
        expect(cls[:good]).to eq(0.1)
        expect(cls[:poor]).to eq(0.25)
        expect(cls[:unit]).to eq('score')
        expect(cls[:name]).to eq('Cumulative Layout Shift')
      end
    end
  end
  
  describe 'scopes' do
    describe '.core_web_vitals' do
      it 'returns only LCP, FID, and CLS metrics' do
        lcp = create(:performance_metric, :lcp)
        fid = create(:performance_metric, :fid)
        cls = create(:performance_metric, :cls)
        ttfb = create(:performance_metric, :ttfb)
        
        expect(PerformanceMetric.core_web_vitals).to include(lcp, fid, cls)
        expect(PerformanceMetric.core_web_vitals).not_to include(ttfb)
      end
    end
    
    describe '.by_type' do
      it 'returns metrics of specified type' do
        lcp1 = create(:performance_metric, :lcp)
        lcp2 = create(:performance_metric, :lcp)
        fid = create(:performance_metric, :fid)
        
        expect(PerformanceMetric.by_type('lcp')).to include(lcp1, lcp2)
        expect(PerformanceMetric.by_type('lcp')).not_to include(fid)
      end
    end
    
    describe '.poor_performance' do
      it 'returns metrics with poor status' do
        good = create(:performance_metric, :good_performance)
        needs_improvement = create(:performance_metric, :needs_improvement)
        poor = create(:performance_metric, :poor_performance)
        
        expect(PerformanceMetric.poor_performance).to include(poor)
        expect(PerformanceMetric.poor_performance).not_to include(good, needs_improvement)
      end
    end
    
    describe '.good_performance' do
      it 'returns metrics with good status' do
        good = create(:performance_metric, :good_performance)
        needs_improvement = create(:performance_metric, :needs_improvement)
        poor = create(:performance_metric, :poor_performance)
        
        expect(PerformanceMetric.good_performance).to include(good)
        expect(PerformanceMetric.good_performance).not_to include(needs_improvement, poor)
      end
    end
  end
  
  describe 'callbacks' do
    describe 'before_save' do
      context '#calculate_threshold_status' do
        it 'sets status to good for values below good threshold' do
          metric = build(:performance_metric, metric_type: 'lcp', value: 2000)
          metric.save!
          expect(metric.threshold_status).to eq('good')
        end
        
        it 'sets status to needs_improvement for values between thresholds' do
          metric = build(:performance_metric, metric_type: 'lcp', value: 3000)
          metric.save!
          expect(metric.threshold_status).to eq('needs_improvement')
        end
        
        it 'sets status to poor for values above poor threshold' do
          metric = build(:performance_metric, metric_type: 'lcp', value: 5000)
          metric.save!
          expect(metric.threshold_status).to eq('poor')
        end
        
        it 'handles CLS score thresholds correctly' do
          good_cls = build(:performance_metric, metric_type: 'cls', value: 0.05)
          needs_improvement_cls = build(:performance_metric, metric_type: 'cls', value: 0.15)
          poor_cls = build(:performance_metric, metric_type: 'cls', value: 0.30)
          
          good_cls.save!
          needs_improvement_cls.save!
          poor_cls.save!
          
          expect(good_cls.threshold_status).to eq('good')
          expect(needs_improvement_cls.threshold_status).to eq('needs_improvement')
          expect(poor_cls.threshold_status).to eq('poor')
        end
      end
      
      context '#set_thresholds' do
        it 'sets threshold values from constants' do
          metric = build(:performance_metric, metric_type: 'lcp', value: 2000)
          metric.save!
          
          expect(metric.threshold_good).to eq(2500)
          expect(metric.threshold_poor).to eq(4000)
          expect(metric.unit).to eq('ms')
        end
        
        it 'sets appropriate unit for each metric type' do
          lcp = create(:performance_metric, metric_type: 'lcp')
          cls = create(:performance_metric, metric_type: 'cls')
          
          expect(lcp.unit).to eq('ms')
          expect(cls.unit).to eq('score')
        end
      end
    end
  end
  
  describe 'instance methods' do
    describe '#display_name' do
      it 'returns friendly name for known metric types' do
        lcp = build(:performance_metric, metric_type: 'lcp')
        expect(lcp.display_name).to eq('Largest Contentful Paint')
        
        fid = build(:performance_metric, metric_type: 'fid')
        expect(fid.display_name).to eq('First Input Delay')
        
        cls = build(:performance_metric, metric_type: 'cls')
        expect(cls.display_name).to eq('Cumulative Layout Shift')
      end
      
      it 'humanizes unknown metric types' do
        metric = build(:performance_metric)
        allow(metric).to receive(:metric_type).and_return('unknown_metric')
        expect(metric.display_name).to eq('Unknown metric')
      end
    end
    
    describe '#display_value' do
      it 'formats millisecond values with ms suffix' do
        metric = build(:performance_metric, value: 2500.5, unit: 'ms')
        expect(metric.display_value).to eq('2500ms')
      end
      
      it 'formats score values with appropriate precision' do
        metric = build(:performance_metric, value: 0.12345, unit: 'score')
        expect(metric.display_value).to eq('0.123')
      end
      
      it 'handles other units with generic formatting' do
        metric = build(:performance_metric, value: 42, unit: 'points')
        expect(metric.display_value).to eq('42.0 points')
      end
      
      it 'handles nil unit gracefully' do
        metric = build(:performance_metric, value: 100, unit: nil)
        expect(metric.display_value).to eq('100.0 ')
      end
    end
    
    describe '#is_core_web_vital?' do
      it 'returns true for LCP, FID, and CLS' do
        expect(build(:performance_metric, :lcp).is_core_web_vital?).to be true
        expect(build(:performance_metric, :fid).is_core_web_vital?).to be true
        expect(build(:performance_metric, :cls).is_core_web_vital?).to be true
      end
      
      it 'returns false for other metrics' do
        expect(build(:performance_metric, :ttfb).is_core_web_vital?).to be false
        expect(build(:performance_metric, :fcp).is_core_web_vital?).to be false
        expect(build(:performance_metric, :speed_index).is_core_web_vital?).to be false
        expect(build(:performance_metric, :total_blocking_time).is_core_web_vital?).to be false
      end
    end
    
    describe '#threshold_color' do
      it 'returns green for good status' do
        metric = build(:performance_metric, threshold_status: :good)
        expect(metric.threshold_color).to eq('green')
      end
      
      it 'returns yellow for needs_improvement status' do
        metric = build(:performance_metric, threshold_status: :needs_improvement)
        expect(metric.threshold_color).to eq('yellow')
      end
      
      it 'returns red for poor status' do
        metric = build(:performance_metric, threshold_status: :poor)
        expect(metric.threshold_color).to eq('red')
      end
      
      it 'returns gray for unknown status' do
        metric = build(:performance_metric)
        allow(metric).to receive(:threshold_status).and_return('unknown')
        expect(metric.threshold_color).to eq('gray')
      end
    end
    
    describe '#score_impact' do
      context 'with score_contribution set' do
        it 'returns full contribution for good status' do
          metric = build(:performance_metric, threshold_status: :good, score_contribution: 20)
          expect(metric.score_impact).to eq(20)
        end
        
        it 'returns 70% contribution for needs_improvement status' do
          metric = build(:performance_metric, threshold_status: :needs_improvement, score_contribution: 20)
          expect(metric.score_impact).to eq(14.0)
        end
        
        it 'returns 30% contribution for poor status' do
          metric = build(:performance_metric, threshold_status: :poor, score_contribution: 20)
          expect(metric.score_impact).to eq(6.0)
        end
      end
      
      context 'without score_contribution set' do
        it 'uses default value of 10' do
          metric = build(:performance_metric, threshold_status: :good, score_contribution: nil)
          expect(metric.score_impact).to eq(10)
          
          metric.threshold_status = :needs_improvement
          expect(metric.score_impact).to eq(7.0)
          
          metric.threshold_status = :poor
          expect(metric.score_impact).to eq(3.0)
        end
      end
      
      it 'returns 0 for unknown status' do
        metric = build(:performance_metric, score_contribution: 20)
        allow(metric).to receive(:threshold_status).and_return('unknown')
        expect(metric.score_impact).to eq(0)
      end
    end
  end
  
  describe 'database columns' do
    it { should have_db_column(:audit_report_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:website_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:metric_type).of_type(:string) }
    it { should have_db_column(:value).of_type(:decimal) }
    it { should have_db_column(:unit).of_type(:string) }
    it { should have_db_column(:threshold_status).of_type(:integer) }
    it { should have_db_column(:threshold_good).of_type(:decimal) }
    it { should have_db_column(:threshold_poor).of_type(:decimal) }
    it { should have_db_column(:score_contribution).of_type(:integer) }
  end
  
  describe 'database indexes' do
    it { should have_db_index(:audit_report_id) }
    it { should have_db_index(:website_id) }
    it { should have_db_index(:metric_type) }
    it { should have_db_index(:threshold_status) }
  end
end