class PerformanceAnalysisJob < ApplicationJob
  queue_as :analysis
  queue_with_priority 8  # Lower priority than audit jobs

  def perform(audit_report_id)
    audit_report = AuditReport.find(audit_report_id)
    website = audit_report.website

    log_job_execution("Starting performance analysis",
                      audit_report_id: audit_report.id,
                      website_id: website.id)

    begin
      # Analyze trends compared to previous reports
      trend_analysis = analyze_performance_trends(website, audit_report)

      # Identify performance issues
      performance_issues = identify_performance_issues(audit_report)

      # Calculate performance insights
      insights = generate_performance_insights(audit_report, trend_analysis)

      # Update audit report with analysis
      audit_report.update!(
        analysis_data: {
          trends: trend_analysis,
          issues: performance_issues,
          insights: insights,
          analyzed_at: Time.current,
          analysis_version: "1.0"
        }
      )

      # Check for performance alerts
      check_performance_alerts(website, audit_report, performance_issues)

      log_job_execution("Performance analysis completed",
                        audit_report_id: audit_report.id,
                        issues_found: performance_issues.size,
                        insights_generated: insights.size)

    rescue => e
      log_job_execution("Performance analysis failed",
                        level: :error,
                        audit_report_id: audit_report.id,
                        error: e.message)
      raise e
    end
  end

  private

  def analyze_performance_trends(website, current_report)
    # Get previous reports for comparison (last 30 days)
    previous_reports = website.audit_reports
                             .where("created_at > ? AND id != ?", 30.days.ago, current_report.id)
                             .where.not(overall_score: nil)
                             .order(created_at: :desc)
                             .limit(10)

    return { status: "insufficient_data" } if previous_reports.count < 2

    trends = {}

    # Overall score trend
    scores = previous_reports.pluck(:overall_score, :created_at)
    current_score = current_report.overall_score

    if scores.any? && current_score
      avg_previous_score = scores.map(&:first).sum.to_f / scores.size
      score_change = current_score - avg_previous_score

      trends[:overall_score] = {
        current: current_score,
        previous_average: avg_previous_score.round(1),
        change: score_change.round(1),
        trend: determine_trend(score_change),
        change_percentage: ((score_change / avg_previous_score) * 100).round(1)
      }
    end

    # Core Web Vitals trends
    trends[:core_web_vitals] = analyze_core_vitals_trends(website, current_report)

    # Performance grade progression
    trends[:grade_progression] = analyze_grade_progression(website, current_report)

    trends
  end

  def analyze_core_vitals_trends(website, current_report)
    # Get LCP, FID, CLS trends
    vitals_trends = {}

    [ "largest_contentful_paint", "first_input_delay", "cumulative_layout_shift" ].each do |metric|
      current_value = current_report.performance_metrics
                                    .find_by(metric_name: metric)&.metric_value

      if current_value
        previous_values = website.audit_reports
                                .joins(:performance_metrics)
                                .where(performance_metrics: { metric_name: metric })
                                .where("audit_reports.created_at > ?", 30.days.ago)
                                .where.not(id: current_report.id)
                                .limit(5)
                                .pluck("performance_metrics.metric_value")

        if previous_values.any?
          avg_previous = previous_values.sum.to_f / previous_values.size
          change = current_value - avg_previous

          vitals_trends[metric] = {
            current: current_value,
            previous_average: avg_previous.round(2),
            change: change.round(2),
            trend: determine_trend(change, reverse: metric == "cumulative_layout_shift"),
            improvement_needed: assess_vital_performance(metric, current_value)
          }
        end
      end
    end

    vitals_trends
  end

  def analyze_grade_progression(website, current_report)
    recent_grades = website.audit_reports
                          .where("created_at > ?", 60.days.ago)
                          .where.not(overall_score: nil)
                          .order(created_at: :desc)
                          .limit(10)
                          .pluck(:overall_score, :created_at)
                          .map { |score, date| { grade: grade_from_score(score), date: date, score: score } }

    return {} if recent_grades.empty?

    current_grade = grade_from_score(current_report.overall_score || 0)

    {
      current_grade: current_grade,
      grade_history: recent_grades,
      grade_stability: calculate_grade_stability(recent_grades),
      improvement_streak: calculate_improvement_streak(recent_grades)
    }
  end

  def identify_performance_issues(audit_report)
    issues = []
    raw_data = audit_report.raw_data || {}

    # Check Core Web Vitals issues
    if raw_data[:lcp] && raw_data[:lcp] > 2500
      severity = raw_data[:lcp] > 4000 ? "critical" : "warning"
      issues << {
        type: "core_web_vitals",
        metric: "LCP",
        severity: severity,
        current_value: raw_data[:lcp],
        threshold: 2500,
        impact: "User experience and SEO rankings",
        description: "Largest Contentful Paint is #{raw_data[:lcp]}ms (target: <2500ms)"
      }
    end

    if raw_data[:fid] && raw_data[:fid] > 100
      severity = raw_data[:fid] > 300 ? "critical" : "warning"
      issues << {
        type: "core_web_vitals",
        metric: "FID",
        severity: severity,
        current_value: raw_data[:fid],
        threshold: 100,
        impact: "User interaction responsiveness",
        description: "First Input Delay is #{raw_data[:fid]}ms (target: <100ms)"
      }
    end

    if raw_data[:cls] && raw_data[:cls] > 0.1
      severity = raw_data[:cls] > 0.25 ? "critical" : "warning"
      issues << {
        type: "core_web_vitals",
        metric: "CLS",
        severity: severity,
        current_value: raw_data[:cls],
        threshold: 0.1,
        impact: "Visual stability and user experience",
        description: "Cumulative Layout Shift is #{raw_data[:cls]} (target: <0.1)"
      }
    end

    # Check page load time
    if raw_data[:load_time] && raw_data[:load_time] > 3000
      severity = raw_data[:load_time] > 5000 ? "critical" : "warning"
      issues << {
        type: "performance",
        metric: "Load Time",
        severity: severity,
        current_value: raw_data[:load_time],
        threshold: 3000,
        impact: "User experience and conversion rates",
        description: "Page load time is #{raw_data[:load_time]}ms (target: <3000ms)"
      }
    end

    # Check page size
    if raw_data[:page_size] && raw_data[:page_size] > 3000
      issues << {
        type: "performance",
        metric: "Page Size",
        severity: "warning",
        current_value: raw_data[:page_size],
        threshold: 3000,
        impact: "Load time and mobile experience",
        description: "Page size is #{raw_data[:page_size]}KB (recommended: <3000KB)"
      }
    end

    # Check SEO issues
    if raw_data[:seo_score] && raw_data[:seo_score] < 80
      issues << {
        type: "seo",
        metric: "SEO Score",
        severity: "warning",
        current_value: raw_data[:seo_score],
        threshold: 80,
        impact: "Search engine visibility",
        description: "SEO score is #{raw_data[:seo_score]}% (target: >80%)"
      }
    end

    # Check security issues
    if raw_data[:security_score] && raw_data[:security_score] < 85
      issues << {
        type: "security",
        metric: "Security Score",
        severity: "warning",
        current_value: raw_data[:security_score],
        threshold: 85,
        impact: "User trust and data protection",
        description: "Security score is #{raw_data[:security_score]}% (target: >85%)"
      }
    end

    issues
  end

  def generate_performance_insights(audit_report, trend_analysis)
    insights = []
    raw_data = audit_report.raw_data || {}

    # Performance insights
    if audit_report.overall_score && audit_report.overall_score >= 90
      insights << {
        type: "success",
        category: "performance",
        title: "Excellent Performance",
        description: "Your website is performing exceptionally well across all metrics.",
        priority: "low",
        action_required: false
      }
    end

    # Trend insights
    if trend_analysis.dig(:overall_score, :trend) == "improving"
      change = trend_analysis.dig(:overall_score, :change)
      insights << {
        type: "positive",
        category: "trends",
        title: "Performance Improving",
        description: "Your performance score has improved by #{change} points compared to recent averages.",
        priority: "low",
        action_required: false
      }
    elsif trend_analysis.dig(:overall_score, :trend) == "declining"
      change = trend_analysis.dig(:overall_score, :change)
      insights << {
        type: "warning",
        category: "trends",
        title: "Performance Declining",
        description: "Your performance score has declined by #{change.abs} points. Consider investigating recent changes.",
        priority: "medium",
        action_required: true
      }
    end

    # Core Web Vitals insights
    vitals_passing = 0
    vitals_total = 3

    if raw_data[:lcp] && raw_data[:lcp] <= 2500
      vitals_passing += 1
    end

    if raw_data[:fid] && raw_data[:fid] <= 100
      vitals_passing += 1
    end

    if raw_data[:cls] && raw_data[:cls] <= 0.1
      vitals_passing += 1
    end

    if vitals_passing == vitals_total
      insights << {
        type: "success",
        category: "core_web_vitals",
        title: "All Core Web Vitals Passing",
        description: "Your website meets all Core Web Vitals thresholds for good user experience.",
        priority: "low",
        action_required: false
      }
    elsif vitals_passing > 0
      insights << {
        type: "warning",
        category: "core_web_vitals",
        title: "Some Core Web Vitals Need Attention",
        description: "#{vitals_passing} out of #{vitals_total} Core Web Vitals are meeting thresholds.",
        priority: "medium",
        action_required: true
      }
    else
      insights << {
        type: "critical",
        category: "core_web_vitals",
        title: "Critical: Core Web Vitals Failing",
        description: "None of your Core Web Vitals are meeting Google's thresholds.",
        priority: "high",
        action_required: true
      }
    end

    # Mobile performance insight
    if raw_data[:load_time] && raw_data[:load_time] > 5000
      insights << {
        type: "warning",
        category: "mobile",
        title: "Mobile Performance Concern",
        description: "Page load time may significantly impact mobile user experience.",
        priority: "medium",
        action_required: true,
        suggested_actions: [
          "Optimize images for mobile devices",
          "Implement lazy loading",
          "Minimize JavaScript execution"
        ]
      }
    end

    insights
  end

  def check_performance_alerts(website, audit_report, issues)
    critical_issues = issues.select { |issue| issue[:severity] == "critical" }

    return if critical_issues.empty?

    # Create alert for critical performance issues
    alert = website.monitoring_alerts.create!(
      alert_type: "performance_degradation",
      severity: "critical",
      title: "Critical Performance Issues Detected",
      description: "#{critical_issues.size} critical performance issues found",
      alert_data: {
        audit_report_id: audit_report.id,
        issues: critical_issues,
        triggered_at: Time.current
      },
      triggered_at: Time.current,
      status: "active"
    )

    # Queue notification job
    PerformanceAlertNotificationJob.perform_later(alert.id)

    log_job_execution("Critical performance alert created",
                      alert_id: alert.id,
                      issues_count: critical_issues.size)
  end

  def determine_trend(change, reverse: false)
    threshold = 2.0

    if reverse
      # For metrics where lower is better (like CLS)
      if change < -threshold
        "improving"
      elsif change > threshold
        "declining"
      else
        "stable"
      end
    else
      # For metrics where higher is better (like performance scores)
      if change > threshold
        "improving"
      elsif change < -threshold
        "declining"
      else
        "stable"
      end
    end
  end

  def assess_vital_performance(metric, value)
    case metric
    when "largest_contentful_paint"
      value > 4000 ? "critical" : value > 2500 ? "needs_improvement" : "good"
    when "first_input_delay"
      value > 300 ? "critical" : value > 100 ? "needs_improvement" : "good"
    when "cumulative_layout_shift"
      value > 0.25 ? "critical" : value > 0.1 ? "needs_improvement" : "good"
    end
  end

  def grade_from_score(score)
    case score
    when 90..100 then "A"
    when 80..89 then "B"
    when 70..79 then "C"
    when 60..69 then "D"
    else "F"
    end
  end

  def calculate_grade_stability(grade_history)
    return "unknown" if grade_history.empty?

    grades = grade_history.map { |g| g[:grade] }
    unique_grades = grades.uniq

    if unique_grades.size == 1
      "very_stable"
    elsif unique_grades.size <= 2
      "stable"
    elsif unique_grades.size <= 3
      "moderate"
    else
      "volatile"
    end
  end

  def calculate_improvement_streak(grade_history)
    return 0 if grade_history.size < 2

    grade_values = { "F" => 1, "D" => 2, "C" => 3, "B" => 4, "A" => 5 }
    streak = 0

    grade_history.each_cons(2) do |current, previous|
      current_value = grade_values[current[:grade]]
      previous_value = grade_values[previous[:grade]]

      if current_value > previous_value
        streak += 1
      else
        break
      end
    end

    streak
  end
end
