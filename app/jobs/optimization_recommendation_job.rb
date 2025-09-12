class OptimizationRecommendationJob < ApplicationJob
  queue_as :recommendations
  queue_with_priority 9  # Lowest priority for recommendation generation

  def perform(audit_report_id)
    audit_report = AuditReport.find(audit_report_id)
    website = audit_report.website

    log_job_execution("Starting optimization recommendation generation",
                      audit_report_id: audit_report.id,
                      website_id: website.id)

    begin
      # Generate recommendations based on audit results
      recommendations = generate_recommendations(audit_report)

      # Prioritize recommendations by impact and effort
      prioritized_recommendations = prioritize_recommendations(recommendations, audit_report)

      # Store recommendations
      store_recommendations(audit_report, prioritized_recommendations)

      log_job_execution("Optimization recommendations generated",
                        audit_report_id: audit_report.id,
                        recommendations_count: prioritized_recommendations.size)

    rescue => e
      log_job_execution("Recommendation generation failed",
                        level: :error,
                        audit_report_id: audit_report.id,
                        error: e.message)
      raise e
    end
  end

  private

  def generate_recommendations(audit_report)
    recommendations = []
    raw_data = audit_report.raw_data || {}
    issues = audit_report.analysis_data&.dig("issues") || []

    # Core Web Vitals recommendations
    recommendations.concat(generate_lcp_recommendations(raw_data))
    recommendations.concat(generate_fid_recommendations(raw_data))
    recommendations.concat(generate_cls_recommendations(raw_data))

    # Performance recommendations
    recommendations.concat(generate_performance_recommendations(raw_data))

    # SEO recommendations
    recommendations.concat(generate_seo_recommendations(raw_data))

    # Security recommendations
    recommendations.concat(generate_security_recommendations(raw_data))

    # Accessibility recommendations
    recommendations.concat(generate_accessibility_recommendations(raw_data))

    recommendations
  end

  def generate_lcp_recommendations(raw_data)
    return [] unless raw_data[:lcp] && raw_data[:lcp] > 2500

    recommendations = []
    lcp_value = raw_data[:lcp]

    if lcp_value > 4000
      recommendations << {
        type: "performance",
        category: "core_web_vitals",
        metric: "LCP",
        title: "Optimize Largest Contentful Paint (Critical)",
        description: "Your LCP is significantly above the recommended threshold. This severely impacts user experience and SEO rankings.",
        current_value: lcp_value,
        target_value: "<2500ms",
        impact: "high",
        effort: "medium",
        priority: "critical",
        technical_details: {
          issue: "Slow loading of largest content element",
          root_causes: [
            "Large, unoptimized images",
            "Slow server response times",
            "Render-blocking resources",
            "Inefficient critical resource prioritization"
          ]
        },
        recommendations: [
          {
            action: "Optimize Images",
            description: "Compress and convert images to modern formats (WebP, AVIF)",
            implementation: "Use responsive images with proper sizing and lazy loading",
            effort: "medium",
            impact: "high"
          },
          {
            action: "Improve Server Response Time",
            description: "Optimize backend performance and reduce TTFB",
            implementation: "Implement server-side caching, optimize database queries, use CDN",
            effort: "high",
            impact: "high"
          },
          {
            action: "Prioritize Critical Resources",
            description: "Use resource hints to prioritize loading of LCP element",
            implementation: 'Add rel="preload" for critical resources, optimize critical rendering path',
            effort: "low",
            impact: "medium"
          }
        ],
        estimated_improvement: "40-60% LCP reduction",
        implementation_time: "2-4 weeks"
      }
    elsif lcp_value > 2500
      recommendations << {
        type: "performance",
        category: "core_web_vitals",
        metric: "LCP",
        title: "Improve Largest Contentful Paint",
        description: "Your LCP needs improvement to meet good user experience standards.",
        current_value: lcp_value,
        target_value: "<2500ms",
        impact: "medium",
        effort: "medium",
        priority: "high",
        technical_details: {
          issue: "Moderately slow loading of largest content element"
        },
        recommendations: [
          {
            action: "Image Optimization",
            description: "Optimize and compress images, use next-gen formats",
            implementation: "Convert to WebP/AVIF, implement responsive images",
            effort: "low",
            impact: "medium"
          },
          {
            action: "Resource Prioritization",
            description: "Prioritize loading of above-the-fold content",
            implementation: "Use preload hints, optimize critical CSS",
            effort: "low",
            impact: "medium"
          }
        ],
        estimated_improvement: "20-40% LCP reduction",
        implementation_time: "1-2 weeks"
      }
    end

    recommendations
  end

  def generate_fid_recommendations(raw_data)
    return [] unless raw_data[:fid] && raw_data[:fid] > 100

    recommendations = []
    fid_value = raw_data[:fid]

    recommendations << {
      type: "performance",
      category: "core_web_vitals",
      metric: "FID",
      title: "Reduce First Input Delay",
      description: "Your FID indicates users are experiencing delays when interacting with your page.",
      current_value: fid_value,
      target_value: "<100ms",
      impact: fid_value > 300 ? "high" : "medium",
      effort: "medium",
      priority: fid_value > 300 ? "critical" : "high",
      technical_details: {
        issue: "Main thread blocking during page load",
        root_causes: [
          "Large JavaScript bundles",
          "Inefficient JavaScript execution",
          "Long-running tasks blocking main thread",
          "Third-party scripts impact"
        ]
      },
      recommendations: [
        {
          action: "Optimize JavaScript",
          description: "Reduce and defer non-critical JavaScript",
          implementation: "Code splitting, tree shaking, defer non-critical scripts",
          effort: "medium",
          impact: "high"
        },
        {
          action: "Break Up Long Tasks",
          description: "Split long-running JavaScript tasks",
          implementation: "Use setTimeout, web workers, or async/await patterns",
          effort: "medium",
          impact: "medium"
        },
        {
          action: "Optimize Third-Party Scripts",
          description: "Audit and optimize third-party script loading",
          implementation: "Load scripts asynchronously, remove unused scripts",
          effort: "low",
          impact: "medium"
        }
      ],
      estimated_improvement: "30-50% FID reduction",
      implementation_time: "2-3 weeks"
    }

    recommendations
  end

  def generate_cls_recommendations(raw_data)
    return [] unless raw_data[:cls] && raw_data[:cls] > 0.1

    recommendations = []
    cls_value = raw_data[:cls]

    recommendations << {
      type: "performance",
      category: "core_web_vitals",
      metric: "CLS",
      title: "Improve Cumulative Layout Shift",
      description: "Your page has visual instability that negatively impacts user experience.",
      current_value: cls_value,
      target_value: "<0.1",
      impact: cls_value > 0.25 ? "high" : "medium",
      effort: "low",
      priority: cls_value > 0.25 ? "critical" : "high",
      technical_details: {
        issue: "Unexpected layout shifts during page load",
        root_causes: [
          "Images without dimensions",
          "Dynamic content insertion",
          "Web fonts causing layout shifts",
          "Ads or embeds without reserved space"
        ]
      },
      recommendations: [
        {
          action: "Set Image Dimensions",
          description: "Always include width and height attributes for images",
          implementation: "Add explicit dimensions or use aspect-ratio CSS",
          effort: "low",
          impact: "high"
        },
        {
          action: "Reserve Space for Dynamic Content",
          description: "Pre-allocate space for ads, embeds, and dynamic content",
          implementation: "Use CSS min-height or placeholder elements",
          effort: "low",
          impact: "high"
        },
        {
          action: "Optimize Font Loading",
          description: "Use font-display: swap and preload key fonts",
          implementation: "Implement proper web font loading strategies",
          effort: "low",
          impact: "medium"
        }
      ],
      estimated_improvement: "50-80% CLS reduction",
      implementation_time: "1 week"
    }

    recommendations
  end

  def generate_performance_recommendations(raw_data)
    recommendations = []

    # Page load time recommendations
    if raw_data[:load_time] && raw_data[:load_time] > 3000
      recommendations << {
        type: "performance",
        category: "loading_speed",
        title: "Improve Page Load Speed",
        description: "Your page load time exceeds recommended thresholds.",
        current_value: raw_data[:load_time],
        target_value: "<3000ms",
        impact: "high",
        effort: "medium",
        priority: "high",
        recommendations: [
          {
            action: "Enable Browser Caching",
            description: "Set appropriate cache headers for static resources",
            effort: "low",
            impact: "high"
          },
          {
            action: "Optimize Critical Rendering Path",
            description: "Inline critical CSS and defer non-critical resources",
            effort: "medium",
            impact: "high"
          },
          {
            action: "Use a Content Delivery Network",
            description: "Distribute content globally for faster delivery",
            effort: "low",
            impact: "medium"
          }
        ]
      }
    end

    # Page size recommendations
    if raw_data[:page_size] && raw_data[:page_size] > 3000
      recommendations << {
        type: "performance",
        category: "resource_optimization",
        title: "Reduce Page Size",
        description: "Your page size is larger than recommended, affecting load times.",
        current_value: "#{raw_data[:page_size]}KB",
        target_value: "<3000KB",
        impact: "medium",
        effort: "low",
        priority: "medium",
        recommendations: [
          {
            action: "Compress Images",
            description: "Optimize images without quality loss",
            effort: "low",
            impact: "high"
          },
          {
            action: "Minify Resources",
            description: "Minify CSS, JavaScript, and HTML",
            effort: "low",
            impact: "medium"
          },
          {
            action: "Remove Unused Code",
            description: "Eliminate unused CSS and JavaScript",
            effort: "medium",
            impact: "medium"
          }
        ]
      }
    end

    recommendations
  end

  def generate_seo_recommendations(raw_data)
    recommendations = []

    if raw_data[:seo_score] && raw_data[:seo_score] < 80
      recommendations << {
        type: "seo",
        category: "search_optimization",
        title: "Improve SEO Score",
        description: "Your SEO score needs improvement for better search visibility.",
        current_value: raw_data[:seo_score],
        target_value: ">85",
        impact: "high",
        effort: "low",
        priority: "high",
        recommendations: []
      }

      # Specific SEO recommendations based on missing elements
      if raw_data[:meta_title_present] == false
        recommendations.last[:recommendations] << {
          action: "Add Meta Title",
          description: "Include unique, descriptive title tags on all pages",
          effort: "low",
          impact: "high"
        }
      end

      if raw_data[:meta_description_present] == false
        recommendations.last[:recommendations] << {
          action: "Add Meta Descriptions",
          description: "Write compelling meta descriptions for all pages",
          effort: "low",
          impact: "medium"
        }
      end

      if raw_data[:h1_count] == 0
        recommendations.last[:recommendations] << {
          action: "Add H1 Headers",
          description: "Include exactly one H1 tag per page with target keywords",
          effort: "low",
          impact: "high"
        }
      end
    end

    recommendations
  end

  def generate_security_recommendations(raw_data)
    recommendations = []

    if raw_data[:security_score] && raw_data[:security_score] < 85
      security_recs = []

      if raw_data[:https_enabled] == false
        security_recs << {
          action: "Enable HTTPS",
          description: "Implement SSL certificate and redirect HTTP to HTTPS",
          effort: "low",
          impact: "high"
        }
      end

      if raw_data[:security_headers] && raw_data[:security_headers] < 6
        security_recs << {
          action: "Add Security Headers",
          description: "Implement CSP, HSTS, X-Frame-Options, and other security headers",
          effort: "low",
          impact: "medium"
        }
      end

      if security_recs.any?
        recommendations << {
          type: "security",
          category: "security_hardening",
          title: "Improve Security Configuration",
          description: "Your site needs security improvements to protect users and data.",
          current_value: raw_data[:security_score],
          target_value: ">90",
          impact: "high",
          effort: "low",
          priority: "high",
          recommendations: security_recs
        }
      end
    end

    recommendations
  end

  def generate_accessibility_recommendations(raw_data)
    recommendations = []

    if raw_data[:accessibility_score] && raw_data[:accessibility_score] < 80
      recommendations << {
        type: "accessibility",
        category: "user_experience",
        title: "Improve Accessibility",
        description: "Your site has accessibility issues that prevent some users from accessing content.",
        current_value: raw_data[:accessibility_score],
        target_value: ">90",
        impact: "medium",
        effort: "medium",
        priority: "medium",
        recommendations: [
          {
            action: "Add Alt Text to Images",
            description: "Provide descriptive alt text for all images",
            effort: "low",
            impact: "high"
          },
          {
            action: "Improve Color Contrast",
            description: "Ensure text meets WCAG color contrast ratios",
            effort: "low",
            impact: "high"
          },
          {
            action: "Add ARIA Labels",
            description: "Include ARIA labels for interactive elements",
            effort: "medium",
            impact: "medium"
          }
        ]
      }
    end

    recommendations
  end

  def prioritize_recommendations(recommendations, audit_report)
    # Calculate priority score based on impact, effort, and current performance
    recommendations.each do |rec|
      impact_score = impact_to_score(rec[:impact])
      effort_score = effort_to_score(rec[:effort])
      urgency_score = urgency_to_score(rec[:priority])

      # Priority score: higher impact, lower effort, higher urgency = higher score
      rec[:priority_score] = (impact_score * 0.4 + (5 - effort_score) * 0.3 + urgency_score * 0.3).round(2)
      rec[:implementation_order] = determine_implementation_order(rec)
    end

    # Sort by priority score (descending)
    recommendations.sort_by { |rec| -rec[:priority_score] }
  end

  def store_recommendations(audit_report, recommendations)
    # Clear existing recommendations for this audit
    audit_report.optimization_recommendations.destroy_all

    recommendations.each_with_index do |rec, index|
      audit_report.optimization_recommendations.create!(
        recommendation_type: rec[:type],
        category: rec[:category],
        title: rec[:title],
        description: rec[:description],
        impact_level: rec[:impact],
        effort_level: rec[:effort],
        priority_level: rec[:priority],
        priority_score: rec[:priority_score],
        implementation_order: index + 1,
        current_value: rec[:current_value]&.to_s,
        target_value: rec[:target_value]&.to_s,
        estimated_improvement: rec[:estimated_improvement],
        implementation_time: rec[:implementation_time],
        technical_details: rec[:technical_details] || {},
        recommendation_data: {
          recommendations: rec[:recommendations] || [],
          metric: rec[:metric],
          generated_at: Time.current
        },
        status: "pending"
      )
    end
  end

  def impact_to_score(impact)
    case impact
    when "high" then 5
    when "medium" then 3
    when "low" then 1
    else 2
    end
  end

  def effort_to_score(effort)
    case effort
    when "low" then 1
    when "medium" then 3
    when "high" then 5
    else 3
    end
  end

  def urgency_to_score(priority)
    case priority
    when "critical" then 5
    when "high" then 4
    when "medium" then 3
    when "low" then 2
    else 2
    end
  end

  def determine_implementation_order(recommendation)
    # Quick wins first (high impact, low effort)
    if recommendation[:impact] == "high" && recommendation[:effort] == "low"
      "quick_win"
    # Critical issues regardless of effort
    elsif recommendation[:priority] == "critical"
      "critical"
    # Major improvements
    elsif recommendation[:impact] == "high"
      "major_improvement"
    # Fill-in tasks
    else
      "fill_in"
    end
  end
end
