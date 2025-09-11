class OptimizationSuggester < ApplicationService
  attr_reader :audit_report, :options
  
  CRITICAL_LCP_THRESHOLD = 4000
  WARNING_LCP_THRESHOLD = 2500
  CRITICAL_FID_THRESHOLD = 300
  WARNING_FID_THRESHOLD = 100
  CRITICAL_CLS_THRESHOLD = 0.25
  WARNING_CLS_THRESHOLD = 0.1
  
  def initialize(audit_report, options = {})
    @audit_report = audit_report
    @options = options
    @priority_level = options[:priority_level] || 'all'
  end
  
  def call
    validate_audit_report!
    
    suggestions = []
    
    # Analyze Core Web Vitals
    suggestions.concat(analyze_core_web_vitals)
    
    # Analyze performance metrics
    suggestions.concat(analyze_performance_metrics)
    
    # Analyze resource optimization
    suggestions.concat(analyze_resource_optimization)
    
    # Analyze SEO factors
    suggestions.concat(analyze_seo_factors)
    
    # Analyze security aspects
    suggestions.concat(analyze_security_aspects)
    
    # Analyze accessibility
    suggestions.concat(analyze_accessibility)
    
    # Filter by priority if specified
    suggestions = filter_by_priority(suggestions) if @priority_level != 'all'
    
    # Sort by priority and impact
    prioritized_suggestions = prioritize_suggestions(suggestions)
    
    # Calculate potential improvements
    improvements = calculate_potential_improvements(prioritized_suggestions)
    
    success(
      suggestions: prioritized_suggestions,
      total_count: prioritized_suggestions.size,
      improvements: improvements,
      audit_report_id: audit_report.id
    )
    
  rescue => e
    Rails.logger.error "OptimizationSuggester Error: #{e.message}"
    failure("Failed to generate suggestions: #{e.message}")
  end
  
  private
  
  def validate_audit_report!
    raise ArgumentError, "Audit report not found" unless audit_report
    raise ArgumentError, "Audit report not completed" unless audit_report.completed?
  end
  
  def analyze_core_web_vitals
    suggestions = []
    cwv_metrics = get_core_web_vitals_metrics
    
    # LCP Analysis
    if cwv_metrics[:lcp]
      lcp_value = cwv_metrics[:lcp]
      
      if lcp_value > CRITICAL_LCP_THRESHOLD
        suggestions << create_lcp_critical_suggestion(lcp_value)
      elsif lcp_value > WARNING_LCP_THRESHOLD
        suggestions << create_lcp_warning_suggestion(lcp_value)
      end
    end
    
    # FID Analysis
    if cwv_metrics[:fid]
      fid_value = cwv_metrics[:fid]
      
      if fid_value > CRITICAL_FID_THRESHOLD
        suggestions << create_fid_critical_suggestion(fid_value)
      elsif fid_value > WARNING_FID_THRESHOLD
        suggestions << create_fid_warning_suggestion(fid_value)
      end
    end
    
    # CLS Analysis
    if cwv_metrics[:cls]
      cls_value = cwv_metrics[:cls]
      
      if cls_value > CRITICAL_CLS_THRESHOLD
        suggestions << create_cls_critical_suggestion(cls_value)
      elsif cls_value > WARNING_CLS_THRESHOLD
        suggestions << create_cls_warning_suggestion(cls_value)
      end
    end
    
    suggestions
  end
  
  def get_core_web_vitals_metrics
    metrics = {}
    
    lcp_metric = audit_report.performance_metrics.find_by(metric_name: 'largest_contentful_paint')
    metrics[:lcp] = lcp_metric.metric_value if lcp_metric
    
    fid_metric = audit_report.performance_metrics.find_by(metric_name: 'first_input_delay')
    metrics[:fid] = fid_metric.metric_value if fid_metric
    
    cls_metric = audit_report.performance_metrics.find_by(metric_name: 'cumulative_layout_shift')
    metrics[:cls] = cls_metric.metric_value if cls_metric
    
    metrics
  end
  
  def create_lcp_critical_suggestion(value)
    {
      type: 'performance',
      category: 'core_web_vitals',
      metric: 'LCP',
      priority: 'critical',
      impact: 'high',
      effort: 'medium',
      title: 'Critical: Optimize Largest Contentful Paint',
      description: "LCP is #{value}ms (target: <2500ms). This severely impacts user experience and SEO.",
      current_value: value,
      target_value: 2500,
      actions: [
        {
          title: 'Optimize Images',
          steps: [
            'Convert images to WebP/AVIF format',
            'Implement responsive images with srcset',
            'Use lazy loading for below-fold images',
            'Optimize image file sizes (compress without quality loss)'
          ],
          expected_improvement: '30-50% LCP reduction',
          effort: 'low'
        },
        {
          title: 'Improve Server Response',
          steps: [
            'Enable server-side caching',
            'Optimize database queries',
            'Use a Content Delivery Network (CDN)',
            'Upgrade hosting infrastructure if needed'
          ],
          expected_improvement: '20-40% TTFB reduction',
          effort: 'medium'
        },
        {
          title: 'Resource Loading Optimization',
          steps: [
            'Preload critical resources with rel="preload"',
            'Remove render-blocking resources',
            'Inline critical CSS',
            'Defer non-critical JavaScript'
          ],
          expected_improvement: '15-30% LCP improvement',
          effort: 'medium'
        }
      ],
      resources: [
        { title: 'Web.dev LCP Guide', url: 'https://web.dev/lcp/' },
        { title: 'Chrome DevTools Performance', url: 'https://developer.chrome.com/docs/devtools/performance/' }
      ]
    }
  end
  
  def create_lcp_warning_suggestion(value)
    {
      type: 'performance',
      category: 'core_web_vitals',
      metric: 'LCP',
      priority: 'high',
      impact: 'medium',
      effort: 'low',
      title: 'Improve Largest Contentful Paint',
      description: "LCP is #{value}ms (target: <2500ms). Some optimization needed.",
      current_value: value,
      target_value: 2500,
      actions: [
        {
          title: 'Quick Wins',
          steps: [
            'Compress images using modern formats',
            'Add width and height attributes to images',
            'Preload the LCP element',
            'Reduce server response time'
          ],
          expected_improvement: '15-25% LCP reduction',
          effort: 'low'
        }
      ]
    }
  end
  
  def create_fid_critical_suggestion(value)
    {
      type: 'performance',
      category: 'core_web_vitals',
      metric: 'FID',
      priority: 'critical',
      impact: 'high',
      effort: 'medium',
      title: 'Critical: Reduce First Input Delay',
      description: "FID is #{value}ms (target: <100ms). Users experience significant interaction delays.",
      current_value: value,
      target_value: 100,
      actions: [
        {
          title: 'JavaScript Optimization',
          steps: [
            'Break up long-running JavaScript tasks',
            'Use web workers for heavy computations',
            'Implement code splitting',
            'Remove unused JavaScript'
          ],
          expected_improvement: '40-60% FID reduction',
          effort: 'medium'
        },
        {
          title: 'Third-Party Script Management',
          steps: [
            'Audit and remove unnecessary third-party scripts',
            'Load third-party scripts asynchronously',
            'Use facades for embedded content',
            'Implement script loading priorities'
          ],
          expected_improvement: '20-40% FID improvement',
          effort: 'low'
        }
      ]
    }
  end
  
  def create_fid_warning_suggestion(value)
    {
      type: 'performance',
      category: 'core_web_vitals',
      metric: 'FID',
      priority: 'high',
      impact: 'medium',
      effort: 'low',
      title: 'Optimize First Input Delay',
      description: "FID is #{value}ms (target: <100ms). Minor optimization recommended.",
      current_value: value,
      target_value: 100,
      actions: [
        {
          title: 'Quick Optimizations',
          steps: [
            'Defer non-critical JavaScript',
            'Minimize main thread work',
            'Use passive event listeners',
            'Optimize event handlers'
          ],
          expected_improvement: '20-30% FID reduction',
          effort: 'low'
        }
      ]
    }
  end
  
  def create_cls_critical_suggestion(value)
    {
      type: 'performance',
      category: 'core_web_vitals',
      metric: 'CLS',
      priority: 'critical',
      impact: 'high',
      effort: 'low',
      title: 'Critical: Fix Cumulative Layout Shift',
      description: "CLS is #{value.round(3)} (target: <0.1). Significant visual instability detected.",
      current_value: value,
      target_value: 0.1,
      actions: [
        {
          title: 'Prevent Layout Shifts',
          steps: [
            'Add explicit dimensions to all images and videos',
            'Reserve space for ad slots and embeds',
            'Avoid inserting content above existing content',
            'Use CSS aspect-ratio for responsive elements'
          ],
          expected_improvement: '60-80% CLS reduction',
          effort: 'low'
        },
        {
          title: 'Font Loading Optimization',
          steps: [
            'Use font-display: optional or swap',
            'Preload critical fonts',
            'Ensure fallback fonts have similar metrics',
            'Avoid FOIT (Flash of Invisible Text)'
          ],
          expected_improvement: '20-30% CLS improvement',
          effort: 'low'
        }
      ]
    }
  end
  
  def create_cls_warning_suggestion(value)
    {
      type: 'performance',
      category: 'core_web_vitals',
      metric: 'CLS',
      priority: 'medium',
      impact: 'medium',
      effort: 'low',
      title: 'Reduce Cumulative Layout Shift',
      description: "CLS is #{value.round(3)} (target: <0.1). Some layout stability improvements needed.",
      current_value: value,
      target_value: 0.1,
      actions: [
        {
          title: 'Layout Stability',
          steps: [
            'Define image dimensions',
            'Avoid dynamic content injection',
            'Use transform animations instead of layout properties',
            'Test on various devices and connections'
          ],
          expected_improvement: '30-50% CLS reduction',
          effort: 'low'
        }
      ]
    }
  end
  
  def analyze_performance_metrics
    suggestions = []
    
    # Page load time
    load_time = audit_report.performance_metrics.find_by(metric_name: 'load_complete')&.metric_value
    if load_time && load_time > 5000
      suggestions << {
        type: 'performance',
        category: 'loading',
        priority: 'high',
        impact: 'high',
        effort: 'medium',
        title: 'Reduce Page Load Time',
        description: "Page takes #{(load_time / 1000.0).round(1)}s to load completely",
        actions: [
          {
            title: 'Performance Optimizations',
            steps: [
              'Enable browser caching',
              'Minify CSS, JavaScript, and HTML',
              'Enable compression (gzip/brotli)',
              'Optimize critical rendering path'
            ]
          }
        ]
      }
    end
    
    # Total page size
    page_size = audit_report.performance_metrics.find_by(metric_name: 'total_page_size')&.metric_value
    if page_size && page_size > 3_000_000  # 3MB
      suggestions << {
        type: 'performance',
        category: 'resources',
        priority: 'medium',
        impact: 'medium',
        effort: 'low',
        title: 'Reduce Page Size',
        description: "Page size is #{(page_size / 1_000_000.0).round(1)}MB",
        actions: [
          {
            title: 'Resource Optimization',
            steps: [
              'Compress and optimize images',
              'Remove unused CSS and JavaScript',
              'Use code splitting',
              'Implement lazy loading'
            ]
          }
        ]
      }
    end
    
    suggestions
  end
  
  def analyze_resource_optimization
    suggestions = []
    
    # Number of requests
    request_count = audit_report.performance_metrics.find_by(metric_name: 'total_requests')&.metric_value
    if request_count && request_count > 100
      suggestions << {
        type: 'performance',
        category: 'resources',
        priority: 'medium',
        impact: 'medium',
        effort: 'medium',
        title: 'Reduce Number of HTTP Requests',
        description: "Page makes #{request_count} HTTP requests",
        actions: [
          {
            title: 'Request Optimization',
            steps: [
              'Combine CSS and JavaScript files',
              'Use CSS sprites for small images',
              'Inline small CSS and JavaScript',
              'Remove unnecessary resources'
            ]
          }
        ]
      }
    end
    
    suggestions
  end
  
  def analyze_seo_factors
    suggestions = []
    raw_data = audit_report.raw_data || {}
    
    # Check for missing meta tags
    if raw_data.dig('html_analysis', 'meta_description').blank?
      suggestions << {
        type: 'seo',
        category: 'meta_tags',
        priority: 'high',
        impact: 'high',
        effort: 'low',
        title: 'Add Meta Description',
        description: 'Page is missing a meta description tag',
        actions: [
          {
            title: 'SEO Optimization',
            steps: [
              'Add unique meta description (150-160 characters)',
              'Include target keywords naturally',
              'Write compelling copy to improve CTR',
              'Avoid duplicate descriptions across pages'
            ]
          }
        ]
      }
    end
    
    # Check H1 tags
    h1_count = raw_data.dig('html_analysis', 'h1_count') || 0
    if h1_count != 1
      suggestions << {
        type: 'seo',
        category: 'headings',
        priority: 'medium',
        impact: 'medium',
        effort: 'low',
        title: h1_count == 0 ? 'Add H1 Tag' : 'Use Single H1 Tag',
        description: h1_count == 0 ? 'Page has no H1 tag' : "Page has #{h1_count} H1 tags",
        actions: [
          {
            title: 'Heading Structure',
            steps: [
              'Use exactly one H1 tag per page',
              'Include primary keyword in H1',
              'Keep H1 concise and descriptive',
              'Use H2-H6 for subheadings'
            ]
          }
        ]
      }
    end
    
    suggestions
  end
  
  def analyze_security_aspects
    suggestions = []
    raw_data = audit_report.raw_data || {}
    
    # HTTPS check
    unless audit_report.website.url.start_with?('https://')
      suggestions << {
        type: 'security',
        category: 'encryption',
        priority: 'critical',
        impact: 'high',
        effort: 'low',
        title: 'Enable HTTPS',
        description: 'Site is not using HTTPS encryption',
        actions: [
          {
            title: 'Security Implementation',
            steps: [
              'Obtain SSL certificate (Let\'s Encrypt for free)',
              'Configure server for HTTPS',
              'Redirect all HTTP traffic to HTTPS',
              'Update internal links to use HTTPS'
            ]
          }
        ]
      }
    end
    
    # Security headers
    headers = raw_data.dig('http_metrics', 'headers') || {}
    missing_headers = []
    
    missing_headers << 'Strict-Transport-Security' unless headers['strict_transport_security']
    missing_headers << 'X-Frame-Options' unless headers['x_frame_options']
    missing_headers << 'X-Content-Type-Options' unless headers['x_content_type_options']
    missing_headers << 'Content-Security-Policy' unless headers['content_security_policy']
    
    if missing_headers.any?
      suggestions << {
        type: 'security',
        category: 'headers',
        priority: 'high',
        impact: 'medium',
        effort: 'low',
        title: 'Add Security Headers',
        description: "Missing security headers: #{missing_headers.join(', ')}",
        actions: [
          {
            title: 'Header Implementation',
            steps: missing_headers.map { |h| "Add #{h} header" }
          }
        ]
      }
    end
    
    suggestions
  end
  
  def analyze_accessibility
    suggestions = []
    raw_data = audit_report.raw_data || {}
    
    # Images without alt text
    images_without_alt = raw_data.dig('html_analysis', 'images_without_alt') || 0
    if images_without_alt > 0
      suggestions << {
        type: 'accessibility',
        category: 'images',
        priority: 'medium',
        impact: 'medium',
        effort: 'low',
        title: 'Add Alt Text to Images',
        description: "#{images_without_alt} images are missing alt text",
        actions: [
          {
            title: 'Accessibility Improvement',
            steps: [
              'Add descriptive alt text to all images',
              'Use empty alt="" for decorative images',
              'Include relevant keywords naturally',
              'Keep alt text concise (under 125 characters)'
            ]
          }
        ]
      }
    end
    
    suggestions
  end
  
  def filter_by_priority(suggestions)
    case @priority_level
    when 'critical'
      suggestions.select { |s| s[:priority] == 'critical' }
    when 'high'
      suggestions.select { |s| %w[critical high].include?(s[:priority]) }
    when 'medium'
      suggestions.select { |s| %w[critical high medium].include?(s[:priority]) }
    else
      suggestions
    end
  end
  
  def prioritize_suggestions(suggestions)
    priority_order = { 'critical' => 0, 'high' => 1, 'medium' => 2, 'low' => 3 }
    impact_order = { 'high' => 0, 'medium' => 1, 'low' => 2 }
    effort_order = { 'low' => 0, 'medium' => 1, 'high' => 2 }
    
    suggestions.sort_by do |suggestion|
      [
        priority_order[suggestion[:priority]] || 99,
        impact_order[suggestion[:impact]] || 99,
        effort_order[suggestion[:effort]] || 99
      ]
    end
  end
  
  def calculate_potential_improvements(suggestions)
    improvements = {
      performance_gain: 0,
      seo_improvement: 0,
      security_enhancement: 0,
      accessibility_boost: 0,
      quick_wins: [],
      high_impact: []
    }
    
    suggestions.each do |suggestion|
      # Estimate improvements based on type and impact
      case suggestion[:type]
      when 'performance'
        improvements[:performance_gain] += impact_to_percentage(suggestion[:impact])
      when 'seo'
        improvements[:seo_improvement] += impact_to_percentage(suggestion[:impact])
      when 'security'
        improvements[:security_enhancement] += impact_to_percentage(suggestion[:impact])
      when 'accessibility'
        improvements[:accessibility_boost] += impact_to_percentage(suggestion[:impact])
      end
      
      # Identify quick wins (low effort, high/medium impact)
      if suggestion[:effort] == 'low' && %w[high medium].include?(suggestion[:impact])
        improvements[:quick_wins] << {
          title: suggestion[:title],
          impact: suggestion[:impact],
          type: suggestion[:type]
        }
      end
      
      # Identify high impact items
      if suggestion[:impact] == 'high'
        improvements[:high_impact] << {
          title: suggestion[:title],
          priority: suggestion[:priority],
          type: suggestion[:type]
        }
      end
    end
    
    improvements
  end
  
  def impact_to_percentage(impact)
    case impact
    when 'high' then 30
    when 'medium' then 15
    when 'low' then 5
    else 0
    end
  end
end