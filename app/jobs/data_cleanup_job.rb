class DataCleanupJob < ApplicationJob
  queue_as :maintenance
  queue_with_priority 10  # Lowest priority for maintenance tasks

  # This job runs periodically to clean up old audit data and manage storage
  def perform(cleanup_type: "full")
    log_job_execution("Starting data cleanup",
                      cleanup_type: cleanup_type)

    begin
      case cleanup_type
      when "full"
        perform_full_cleanup
      when "performance_metrics"
        cleanup_performance_metrics
      when "audit_reports"
        cleanup_audit_reports
      when "alerts"
        cleanup_monitoring_alerts
      when "cache"
        cleanup_cache_data
      else
        raise ArgumentError, "Unknown cleanup type: #{cleanup_type}"
      end

      log_job_execution("Data cleanup completed successfully",
                        cleanup_type: cleanup_type)

    rescue => e
      log_job_execution("Data cleanup failed",
                        level: :error,
                        cleanup_type: cleanup_type,
                        error: e.message)
      raise e
    end
  end

  private

  def perform_full_cleanup
    log_job_execution("Performing full data cleanup")

    # Run all cleanup tasks
    cleanup_performance_metrics
    cleanup_audit_reports
    cleanup_monitoring_alerts
    cleanup_cache_data
    cleanup_user_sessions
    vacuum_database
  end

  def cleanup_performance_metrics
    log_job_execution("Cleaning up performance metrics")

    # Remove performance metrics older than retention periods based on subscription
    Account.includes(:subscription, audit_reports: :performance_metrics).find_each do |account|
      retention_days = get_retention_days(account.subscription)
      cutoff_date = retention_days.days.ago

      # Get metrics to delete
      old_metrics = PerformanceMetric.joins(audit_report: :website)
                                     .where(websites: { account_id: account.id })
                                     .where("performance_metrics.created_at < ?", cutoff_date)

      metrics_count = old_metrics.count

      if metrics_count > 0
        old_metrics.delete_all

        log_job_execution("Cleaned up performance metrics for account",
                          account_id: account.id,
                          metrics_deleted: metrics_count,
                          retention_days: retention_days)
      end
    end
  end

  def cleanup_audit_reports
    log_job_execution("Cleaning up audit reports")

    Account.includes(:subscription, :audit_reports).find_each do |account|
      retention_days = get_retention_days(account.subscription)
      cutoff_date = retention_days.days.ago

      # Keep at least the last successful audit for each website
      websites = account.websites.pluck(:id)

      websites.each do |website_id|
        # Get the last successful audit for this website
        last_successful_audit = AuditReport.where(website_id: website_id, status: "completed")
                                           .order(created_at: :desc)
                                           .first

        # Delete old audits (but keep the last successful one)
        old_audits = AuditReport.where(website_id: website_id)
                                .where("created_at < ?", cutoff_date)

        if last_successful_audit
          old_audits = old_audits.where.not(id: last_successful_audit.id)
        end

        audits_count = old_audits.count

        if audits_count > 0
          old_audits.destroy_all  # Use destroy_all to trigger callbacks and cleanup associations

          log_job_execution("Cleaned up audit reports for website",
                            account_id: account.id,
                            website_id: website_id,
                            audits_deleted: audits_count)
        end
      end
    end
  end

  def cleanup_monitoring_alerts
    log_job_execution("Cleaning up monitoring alerts")

    # Keep alerts for different periods based on severity
    alert_retention_periods = {
      "critical" => 90.days,
      "high" => 60.days,
      "medium" => 30.days,
      "low" => 14.days
    }

    alert_retention_periods.each do |severity, retention_period|
      cutoff_date = retention_period.ago

      old_alerts = MonitoringAlert.where(severity: severity)
                                  .where("created_at < ?", cutoff_date)
                                  .where(status: [ "resolved", "acknowledged" ])

      alerts_count = old_alerts.count

      if alerts_count > 0
        old_alerts.delete_all

        log_job_execution("Cleaned up monitoring alerts",
                          severity: severity,
                          alerts_deleted: alerts_count,
                          retention_days: (retention_period / 1.day).to_i)
      end
    end

    # Also clean up very old active alerts (over 6 months)
    very_old_alerts = MonitoringAlert.where("created_at < ?", 6.months.ago)
    very_old_count = very_old_alerts.count

    if very_old_count > 0
      very_old_alerts.delete_all
      log_job_execution("Cleaned up very old alerts",
                        alerts_deleted: very_old_count)
    end
  end

  def cleanup_cache_data
    log_job_execution("Cleaning up cache data")

    # Clean up user notifications older than 30 days
    cleanup_user_notifications

    # Clean up temporary audit data
    cleanup_temporary_audit_data

    # Clean up expired sessions
    cleanup_expired_sessions
  end

  def cleanup_user_notifications
    # Clean up user notifications stored in Rails cache
    User.find_each do |user|
      user_notifications_key = "user_notifications:#{user.id}"
      notifications = Rails.cache.fetch(user_notifications_key) { [] }

      if notifications.any?
        # Keep only notifications from last 30 days
        cutoff_date = 30.days.ago
        filtered_notifications = notifications.select do |notification|
          Time.parse(notification["created_at"]) > cutoff_date
        end

        if filtered_notifications.size != notifications.size
          Rails.cache.write(user_notifications_key, filtered_notifications, expires_in: 30.days)

          log_job_execution("Cleaned up user notifications",
                            user_id: user.id,
                            notifications_removed: notifications.size - filtered_notifications.size)
        end
      end
    end
  end

  def cleanup_temporary_audit_data
    # Clean up any temporary files or data created during audits
    temp_data_keys = Rails.cache.redis&.keys("temp_audit:*") || []

    if temp_data_keys.any?
      expired_count = 0

      temp_data_keys.each do |key|
        # Remove keys older than 24 hours
        if key.match(/temp_audit:(\d+)/)
          timestamp = $1.to_i
          if timestamp < 24.hours.ago.to_i
            Rails.cache.delete(key)
            expired_count += 1
          end
        end
      end

      log_job_execution("Cleaned up temporary audit data",
                        keys_removed: expired_count)
    end
  end

  def cleanup_expired_sessions
    # Clean up expired sessions if using database session store
    if Rails.application.config.session_store == ActionDispatch::Session::ActiveRecordStore
      # This would clean up the sessions table
      # ActiveRecord::SessionStore::Session.where('updated_at < ?', 1.week.ago).delete_all
    end
  end

  def cleanup_user_sessions
    log_job_execution("Cleaning up user sessions")

    # Clean up old user sessions (assuming we track these)
    # This is a placeholder - adjust based on your session management
    if defined?(Session)
      old_sessions = Session.where("created_at < ?", 30.days.ago)
      sessions_count = old_sessions.count

      if sessions_count > 0
        old_sessions.delete_all
        log_job_execution("Cleaned up user sessions",
                          sessions_deleted: sessions_count)
      end
    end
  end

  def vacuum_database
    log_job_execution("Performing database vacuum")

    begin
      # PostgreSQL vacuum to reclaim space after deletions
      if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
        ActiveRecord::Base.connection.execute("VACUUM ANALYZE;")
        log_job_execution("Database vacuum completed")
      end
    rescue => e
      log_job_execution("Database vacuum failed",
                        level: :warn,
                        error: e.message)
      # Don't re-raise vacuum errors
    end
  end

  def get_retention_days(subscription)
    return 30 unless subscription # Default retention for accounts without subscription

    case subscription.plan_name
    when "starter"
      90   # 3 months
    when "professional"
      180  # 6 months
    when "enterprise"
      365  # 1 year
    else
      30   # Default
    end
  end
end

# Recurring cleanup jobs
class DailyCleanupJob < ApplicationJob
  recurring schedule: "0 2 * * *"  # Daily at 2 AM

  def perform
    DataCleanupJob.perform_later(cleanup_type: "cache")
  end
end

class WeeklyCleanupJob < ApplicationJob
  recurring schedule: "0 3 * * 0"  # Weekly on Sunday at 3 AM

  def perform
    DataCleanupJob.perform_later(cleanup_type: "performance_metrics")
  end
end

class MonthlyCleanupJob < ApplicationJob
  recurring schedule: "0 4 1 * *"  # Monthly on the 1st at 4 AM

  def perform
    DataCleanupJob.perform_later(cleanup_type: "full")
  end
end
