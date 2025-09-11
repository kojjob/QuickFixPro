class PerformanceAlertMailer < ApplicationMailer
  default from: 'alerts@speedboost.com',
          reply_to: 'support@speedboost.com'
  
  def critical_performance_alert(user, alert)
    @user = user
    @alert = alert
    @website = alert.website
    @account = @website.account
    @issues = @alert.alert_data['issues'] || []
    @audit_report_id = @alert.alert_data['audit_report_id']
    
    @critical_issues = @issues.select { |issue| issue['severity'] == 'critical' }
    @warning_issues = @issues.select { |issue| issue['severity'] == 'warning' }
    
    @report_url = dashboard_url(host: Rails.application.credentials.dig(:app, :domain) || 'localhost:3000')
    @website_url = "#{@report_url}/websites/#{@website.id}"
    @audit_report_url = "#{@report_url}/websites/#{@website.id}/reports/#{@audit_report_id}"
    
    # Customize subject based on severity and issue count
    subject = build_alert_subject
    
    mail(
      to: @user.email,
      subject: subject,
      template_name: 'critical_performance_alert'
    )
  end
  
  def weekly_performance_summary(user, account, summary_data)
    @user = user
    @account = account
    @summary_data = summary_data
    @websites = @summary_data[:websites] || []
    @total_audits = @summary_data[:total_audits] || 0
    @avg_score_change = @summary_data[:avg_score_change] || 0
    @issues_resolved = @summary_data[:issues_resolved] || 0
    @new_issues = @summary_data[:new_issues] || 0
    
    @dashboard_url = dashboard_url(host: Rails.application.credentials.dig(:app, :domain) || 'localhost:3000')
    
    mail(
      to: @user.email,
      subject: "Weekly Performance Summary - #{Date.current.strftime('%B %d, %Y')}",
      template_name: 'weekly_performance_summary'
    )
  end
  
  def performance_improvement_notification(user, website, improvement_data)
    @user = user
    @website = website
    @account = website.account
    @improvement_data = improvement_data
    @score_improvement = improvement_data[:score_improvement]
    @metric_improvements = improvement_data[:metric_improvements] || {}
    
    @website_url = website_url(@website, host: Rails.application.credentials.dig(:app, :domain) || 'localhost:3000')
    
    mail(
      to: @user.email,
      subject: "🎉 Performance Improved for #{@website.name}",
      template_name: 'performance_improvement_notification'
    )
  end
  
  def monthly_performance_report(user, account, report_data)
    @user = user
    @account = account
    @report_data = report_data
    @month = Date.current.strftime('%B %Y')
    @websites = @report_data[:websites] || []
    @total_audits = @report_data[:total_audits] || 0
    @avg_score = @report_data[:avg_score] || 0
    @score_trend = @report_data[:score_trend] || 'stable'
    @top_performing_site = @report_data[:top_performing_site]
    @needs_attention = @report_data[:needs_attention] || []
    
    @dashboard_url = dashboard_url(host: Rails.application.credentials.dig(:app, :domain) || 'localhost:3000')
    
    mail(
      to: @user.email,
      subject: "Monthly Performance Report - #{@month}",
      template_name: 'monthly_performance_report'
    )
  end
  
  private
  
  def build_alert_subject
    website_name = @website.name
    critical_count = @critical_issues.size
    
    case critical_count
    when 1
      issue = @critical_issues.first
      "🚨 Critical #{issue['metric']} Issue - #{website_name}"
    when 2..3
      "🚨 #{critical_count} Critical Performance Issues - #{website_name}"
    else
      "🚨 Multiple Critical Issues Detected - #{website_name}"
    end
  end
end