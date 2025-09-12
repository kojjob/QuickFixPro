require 'rails_helper'

RSpec.describe AutoFixEngine do
  let(:website) { create(:website) }
  let(:audit_report) { create(:audit_report, website: website) }
  let(:engine) { described_class.new(audit_report) }

  describe '#initialize' do
    it 'initializes with an audit report' do
      expect(engine.audit_report).to eq(audit_report)
    end

    it 'raises error without audit report' do
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
    end
  end

  describe '#detect_issues' do
    context 'when detecting image optimization issues' do
      before do
        audit_report.update(
          raw_results: {
            'opportunities' => {
              'uses-webp-images' => {
                'score' => 0.5,
                'details' => {
                  'items' => [
                    { 'url' => 'image1.jpg', 'wastedBytes' => 150000 },
                    { 'url' => 'image2.png', 'wastedBytes' => 200000 }
                  ]
                }
              },
              'uses-optimized-images' => {
                'score' => 0.3,
                'details' => {
                  'items' => [
                    { 'url' => 'large-image.jpg', 'wastedBytes' => 500000 }
                  ]
                }
              }
            }
          }
        )
      end

      it 'detects unoptimized images' do
        issues = engine.detect_issues
        image_issues = issues.select { |i| i[:type] == :image_optimization }

        expect(image_issues).not_to be_empty
        expect(image_issues.first[:severity]).to eq(:high)
        expect(image_issues.first[:impact]).to include('830KB')
      end

      it 'calculates total bytes that can be saved' do
        issues = engine.detect_issues
        image_issue = issues.find { |i| i[:type] == :image_optimization }

        expect(image_issue[:data][:total_savings]).to eq(850000)
        expect(image_issue[:data][:affected_images].count).to eq(3)
      end
    end

    context 'when detecting caching issues' do
      before do
        audit_report.update(
          raw_results: {
            'audits' => {
              'uses-long-cache-ttl' => {
                'score' => 0.2,
                'details' => {
                  'items' => [
                    { 'url' => 'app.js', 'cacheLifetimeMs' => 0 },
                    { 'url' => 'style.css', 'cacheLifetimeMs' => 3600000 }
                  ]
                }
              }
            }
          }
        )
      end

      it 'detects missing cache headers' do
        issues = engine.detect_issues
        cache_issues = issues.select { |i| i[:type] == :caching_headers }

        expect(cache_issues).not_to be_empty
        expect(cache_issues.first[:severity]).to eq(:medium)
      end
    end

    context 'when detecting CSS optimization issues' do
      before do
        audit_report.update(
          raw_results: {
            'audits' => {
              'render-blocking-resources' => {
                'score' => 0.4,
                'details' => {
                  'items' => [
                    { 'url' => 'style.css', 'wastedMs' => 1200 },
                    { 'url' => 'theme.css', 'wastedMs' => 800 }
                  ]
                }
              },
              'unminified-css' => {
                'score' => 0.5,
                'details' => {
                  'items' => [
                    { 'url' => 'main.css', 'wastedBytes' => 25000 }
                  ]
                }
              }
            }
          }
        )
      end

      it 'detects render-blocking CSS' do
        issues = engine.detect_issues
        css_issues = issues.select { |i| i[:type] == :css_optimization }

        expect(css_issues).not_to be_empty
        expect(css_issues.first[:data][:render_blocking_count]).to eq(2)
      end

      it 'detects unminified CSS' do
        issues = engine.detect_issues
        css_issue = issues.find { |i| i[:type] == :css_optimization }

        expect(css_issue[:data][:unminified_count]).to eq(1)
        expect(css_issue[:data][:potential_savings]).to eq(25000)
      end
    end

    context 'when detecting JavaScript issues' do
      before do
        audit_report.update(
          raw_results: {
            'audits' => {
              'unminified-javascript' => {
                'score' => 0.3,
                'details' => {
                  'items' => [
                    { 'url' => 'app.js', 'wastedBytes' => 45000 },
                    { 'url' => 'vendor.js', 'wastedBytes' => 80000 }
                  ]
                }
              },
              'bootup-time' => {
                'score' => 0.4,
                'details' => {
                  'items' => [
                    { 'url' => 'heavy-script.js', 'scripting' => 2500 }
                  ]
                }
              }
            }
          }
        )
      end

      it 'detects unminified JavaScript' do
        issues = engine.detect_issues
        js_issues = issues.select { |i| i[:type] == :javascript_optimization }

        expect(js_issues).not_to be_empty
        expect(js_issues.first[:data][:unminified_files].count).to eq(2)
        expect(js_issues.first[:data][:total_savings]).to eq(125000)
      end
    end

    it 'prioritizes issues by severity' do
      audit_report.update(
        raw_results: {
          'opportunities' => {
            'uses-webp-images' => { 'score' => 0.1 }, # High severity
            'uses-long-cache-ttl' => { 'score' => 0.5 } # Medium severity
          }
        }
      )

      issues = engine.detect_issues
      expect(issues.first[:severity]).to eq(:high)
      expect(issues.last[:severity]).to eq(:medium)
    end
  end

  describe '#can_auto_fix?' do
    it 'returns true for supported issue types' do
      issue = { type: :image_optimization, auto_fixable: true }
      expect(engine.can_auto_fix?(issue)).to be true
    end

    it 'returns false for unsupported issue types' do
      issue = { type: :custom_fonts, auto_fixable: false }
      expect(engine.can_auto_fix?(issue)).to be false
    end

    it 'returns false for nil issue' do
      expect(engine.can_auto_fix?(nil)).to be false
    end
  end

  describe '#apply_fix' do
    let(:issue) do
      {
        type: :image_optimization,
        auto_fixable: true,
        data: {
          affected_images: [ 'image1.jpg', 'image2.png' ],
          total_savings: 500000
        }
      }
    end

    context 'when applying image optimization fix' do
      it 'creates an optimization task' do
        expect {
          engine.apply_fix(issue)
        }.to change(OptimizationTask, :count).by(1)
      end

      it 'returns success result with details' do
        result = engine.apply_fix(issue)

        expect(result[:success]).to be true
        expect(result[:type]).to eq(:image_optimization)
        expect(result[:message]).to include('2 images')
        expect(result[:estimated_improvement]).to include('488KB')
      end

      it 'tracks the fix in the database' do
        result = engine.apply_fix(issue)

        task = OptimizationTask.last
        expect(task.status).to eq('pending')
        expect(task.fix_type).to eq('image_optimization')
        expect(task.website).to eq(website)
      end
    end

    context 'when applying cache headers fix' do
      let(:cache_issue) do
        {
          type: :caching_headers,
          auto_fixable: true,
          data: {
            missing_cache_resources: [ 'app.js', 'style.css' ],
            recommended_ttl: 31536000 # 1 year
          }
        }
      end

      it 'creates cache configuration' do
        result = engine.apply_fix(cache_issue)

        expect(result[:success]).to be true
        expect(result[:config]).to include('Cache-Control')
        expect(result[:config]).to include('max-age=31536000')
      end
    end

    context 'when applying CSS minification fix' do
      let(:css_issue) do
        {
          type: :css_optimization,
          auto_fixable: true,
          data: {
            unminified_files: [ 'main.css', 'theme.css' ],
            potential_savings: 35000
          }
        }
      end

      it 'schedules CSS minification' do
        result = engine.apply_fix(css_issue)

        expect(result[:success]).to be true
        expect(result[:files_to_process]).to eq(2)
        expect(result[:estimated_reduction]).to include('34KB')
      end
    end

    context 'when fix fails' do
      let(:invalid_issue) { { type: :unknown_type } }

      it 'returns failure result' do
        result = engine.apply_fix(invalid_issue)

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end

      it 'does not create optimization task' do
        expect {
          engine.apply_fix(invalid_issue)
        }.not_to change(OptimizationTask, :count)
      end
    end
  end

  describe '#preview_fix' do
    let(:issue) do
      {
        type: :image_optimization,
        auto_fixable: true,
        data: {
          affected_images: [ 'hero.jpg', 'banner.png' ],
          total_savings: 750000
        }
      }
    end

    it 'returns preview without applying changes' do
      preview = engine.preview_fix(issue)

      expect(preview[:changes]).to be_present
      expect(preview[:estimated_impact]).to be_present
      expect(preview[:risk_level]).to be_present
    end

    it 'does not create any database records' do
      expect {
        engine.preview_fix(issue)
      }.not_to change(OptimizationTask, :count)
    end

    it 'provides before and after comparison' do
      preview = engine.preview_fix(issue)

      expect(preview[:before][:total_size]).to be_present
      expect(preview[:after][:total_size]).to be_present
      expect(preview[:after][:total_size]).to be < preview[:before][:total_size]
    end
  end

  describe '#apply_all_fixes' do
    before do
      audit_report.update(
        raw_results: {
          'opportunities' => {
            'uses-webp-images' => {
              'score' => 0.2,
              'details' => { 'items' => [ { 'url' => 'img.jpg', 'wastedBytes' => 100000 } ] }
            },
            'uses-long-cache-ttl' => {
              'score' => 0.3,
              'details' => { 'items' => [ { 'url' => 'app.js' } ] }
            }
          }
        }
      )
    end

    it 'applies all auto-fixable issues' do
      results = engine.apply_all_fixes

      expect(results[:total_fixes]).to eq(2)
      expect(results[:successful_fixes]).to eq(2)
      expect(results[:failed_fixes]).to eq(0)
    end

    it 'continues on individual fix failure' do
      allow(engine).to receive(:apply_fix).and_return(
        { success: true },
        { success: false, error: 'Test error' }
      )

      results = engine.apply_all_fixes

      expect(results[:successful_fixes]).to eq(1)
      expect(results[:failed_fixes]).to eq(1)
      expect(results[:errors]).to include('Test error')
    end

    it 'estimates total improvement' do
      results = engine.apply_all_fixes

      expect(results[:estimated_improvement]).to be_present
      expect(results[:estimated_improvement][:performance_score]).to be > 0
      expect(results[:estimated_improvement][:load_time_reduction]).to be_present
    end
  end

  describe '#rollback_fix' do
    let(:optimization_task) { create(:optimization_task, website: website, status: 'completed') }

    it 'rollbacks a completed fix' do
      result = engine.rollback_fix(optimization_task)

      expect(result[:success]).to be true
      expect(optimization_task.reload.status).to eq('rolled_back')
    end

    it 'cannot rollback pending fix' do
      optimization_task.update(status: 'pending')
      result = engine.rollback_fix(optimization_task)

      expect(result[:success]).to be false
      expect(result[:error]).to include('Cannot rollback')
    end
  end
end
