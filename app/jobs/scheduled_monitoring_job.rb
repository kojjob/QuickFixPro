class ScheduledMonitoringJob < ApplicationJob
  queue_as :monitoring
  queue_with_priority 6

  # This job runs periodically to check which websites need monitoring
  # In Rails 8 with Solid Queue, this can be configured as a recurring job
  def self.schedule
    # This method can be called by a cron job or scheduled task
    perform_later
  end

  def perform
    log_job_execution("Starting scheduled website monitoring check")

    begin
      # Find websites that are due for monitoring
      websites_due = Website.due_for_monitoring.includes(:account, :subscription)

      log_job_execution("Found websites due for monitoring",
                        websites_count: websites_due.count)

      # Group by monitoring frequency to batch process
      websites_due.group_by(&:monitoring_frequency).each do |frequency, websites|
        process_frequency_batch(frequency, websites)
      end

      log_job_execution("Scheduled monitoring check completed")

    rescue => e
      log_job_execution("Scheduled monitoring check failed",
                        level: :error,
                        error: e.message)
      raise e
    end
  end

  private

  def process_frequency_batch(frequency, websites)
    log_job_execution("Processing #{frequency} monitoring batch",
                      frequency: frequency,
                      websites_count: websites.size)

    websites.each do |website|
      # Check if account has active subscription
      unless can_monitor_website?(website)
        log_job_execution("Skipping website - monitoring not available",
                          website_id: website.id,
                          reason: "Subscription limit reached or inactive")
        next
      end

      # Check if we should throttle monitoring for this account
      if should_throttle_monitoring?(website.account)
        log_job_execution("Throttling monitoring for account",
                          account_id: website.account.id,
                          website_id: website.id)
        next
      end

      # Schedule the audit
      schedule_website_audit(website, frequency)
    end
  end

  def can_monitor_website?(website)
    account = website.account
    subscription = account.subscription

    # Check if subscription is active
    return false unless subscription&.active?

    # Check monitoring limits
    current_month_audits = account.audit_reports
                                  .where("created_at > ?", 1.month.ago)
                                  .count

    monthly_limit = subscription.plan_limits["monthly_audits"] || 0

    return false if current_month_audits >= monthly_limit

    # Check concurrent monitoring limits
    running_audits = account.audit_reports
                            .where(status: "running")
                            .count

    concurrent_limit = subscription.plan_limits["concurrent_audits"] || 1

    return false if running_audits >= concurrent_limit

    true
  end

  def should_throttle_monitoring?(account)
    # Check if too many audits have been run recently for this account
    recent_audits = account.audit_reports
                           .where("created_at > ?", 1.hour.ago)
                           .count

    # Limit to 5 audits per hour per account to prevent abuse
    recent_audits >= 5
  end

  def schedule_website_audit(website, frequency)
    # Determine audit type based on frequency and subscription
    audit_type = determine_audit_type(website, frequency)

    # Add some jitter to prevent all jobs from running at exactly the same time
    delay = rand(0..30).minutes

    WebsiteAuditJob.set(wait: delay).perform_later(
      website.id,
      audit_type: audit_type,
      triggered_by: "scheduled_#{frequency}"
    )

    log_job_execution("Scheduled website audit",
                      website_id: website.id,
                      audit_type: audit_type,
                      frequency: frequency,
                      delay_minutes: delay.to_i / 60)
  end

  def determine_audit_type(website, frequency)
    subscription = website.account.subscription
    return "performance" unless subscription

    # Different audit types based on subscription tier and frequency
    case subscription.plan_name
    when "starter"
      case frequency
      when "daily"
        "performance"
      when "weekly", "monthly"
        "full"
      else
        "performance"
      end
    when "professional"
      case frequency
      when "daily"
        "full"
      when "weekly"
        "lighthouse"
      when "monthly"
        "full"
      else
        "full"
      end
    when "enterprise"
      "full" # Enterprise gets full audits for all frequencies
    else
      "performance"
    end
  end
end

# Rails 8 Solid Queue recurring job configuration
# This would typically be configured in an initializer or via the Solid Queue recurring jobs feature
class ScheduledMonitoringRecurringJob < ApplicationJob
  # Schedule this job to run every 15 minutes
  # In production, this would be configured in the Solid Queue recurring jobs configuration
  recurring schedule: "*/15 * * * *"  # Every 15 minutes

  def perform
    ScheduledMonitoringJob.perform_later
  end
end
