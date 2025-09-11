class PerformanceAlertNotificationJob < ApplicationJob
  queue_as :notifications
  queue_with_priority 3  # High priority for alerts
  
  # Don't retry alert notifications too aggressively
  retry_on StandardError, attempts: 3, wait: 30.seconds
  
  def perform(alert_id)
    alert = MonitoringAlert.find(alert_id)
    website = alert.website
    account = website.account
    
    log_job_execution("Sending performance alert notification",
                      alert_id: alert.id,
                      website_id: website.id,
                      account_id: account.id)
    
    begin
      # Send email notifications to account users
      send_email_notifications(alert, account)
      
      # Send in-app notifications
      create_in_app_notifications(alert, account)
      
      # Send webhook notification if configured
      send_webhook_notification(alert, account) if account.webhook_url.present?
      
      # Update alert as notified
      alert.update!(
        notification_sent_at: Time.current,
        notification_data: {
          email_sent: true,
          in_app_created: true,
          webhook_sent: account.webhook_url.present?,
          notified_at: Time.current
        }
      )
      
      log_job_execution("Performance alert notifications sent successfully",
                        alert_id: alert.id)
      
    rescue => e
      log_job_execution("Failed to send performance alert notifications",
                        level: :error,
                        alert_id: alert.id,
                        error: e.message)
      raise e
    end
  end
  
  private
  
  def send_email_notifications(alert, account)
    # Get users who should receive performance alerts
    notification_users = account.users.joins(:user_roles)
                                     .where(user_roles: { role: ['owner', 'admin'] })
                                     .where(email_notifications: true)
    
    return if notification_users.empty?
    
    notification_users.find_each do |user|
      begin
        PerformanceAlertMailer.critical_performance_alert(user, alert).deliver_now
        
        log_job_execution("Email sent to user",
                          user_id: user.id,
                          email: user.email,
                          alert_id: alert.id)
      rescue => e
        log_job_execution("Failed to send email to user",
                          level: :error,
                          user_id: user.id,
                          email: user.email,
                          error: e.message)
        # Continue with other users
      end
    end
  end
  
  def create_in_app_notifications(alert, account)
    website = alert.website
    issues = alert.alert_data['issues'] || []
    
    notification_data = {
      type: 'performance_alert',
      severity: alert.severity,
      title: alert.title,
      message: build_notification_message(alert, issues),
      website: {
        id: website.id,
        name: website.name,
        url: website.display_url
      },
      issues_count: issues.size,
      action_url: "/websites/#{website.id}/reports/#{alert.alert_data['audit_report_id']}",
      alert_data: alert.alert_data
    }
    
    # Create notifications for relevant users
    account.users.joins(:user_roles)
                 .where(user_roles: { role: ['owner', 'admin', 'member'] })
                 .find_each do |user|
      create_user_notification(user, notification_data)
    end
  end
  
  def create_user_notification(user, notification_data)
    # In a real application, this would create records in a notifications table
    # For now, we'll use Rails.cache as a simple storage mechanism
    user_notifications_key = "user_notifications:#{user.id}"
    existing_notifications = Rails.cache.fetch(user_notifications_key) { [] }
    
    new_notification = {
      id: SecureRandom.uuid,
      created_at: Time.current,
      read: false,
      **notification_data
    }
    
    existing_notifications.prepend(new_notification)
    
    # Keep only the last 50 notifications
    existing_notifications = existing_notifications.first(50)
    
    Rails.cache.write(user_notifications_key, existing_notifications, expires_in: 30.days)
    
    # Broadcast to connected users via Hotwire
    broadcast_notification_to_user(user, new_notification)
  end
  
  def send_webhook_notification(alert, account)
    return unless account.webhook_url.present?
    
    webhook_payload = {
      event: 'performance_alert',
      timestamp: Time.current.iso8601,
      account_id: account.id,
      alert: {
        id: alert.id,
        type: alert.alert_type,
        severity: alert.severity,
        title: alert.title,
        description: alert.description,
        website: {
          id: alert.website.id,
          name: alert.website.name,
          url: alert.website.url
        },
        issues: alert.alert_data['issues'] || [],
        audit_report_id: alert.alert_data['audit_report_id'],
        triggered_at: alert.triggered_at
      }
    }
    
    begin
      response = HTTParty.post(
        account.webhook_url,
        body: webhook_payload.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => 'SpeedBoost-Webhooks/1.0',
          'X-SpeedBoost-Event' => 'performance_alert'
        },
        timeout: 10
      )
      
      if response.success?
        log_job_execution("Webhook notification sent successfully",
                          webhook_url: account.webhook_url,
                          response_code: response.code)
      else
        log_job_execution("Webhook notification failed",
                          level: :warn,
                          webhook_url: account.webhook_url,
                          response_code: response.code,
                          response_body: response.body)
      end
      
    rescue => e
      log_job_execution("Webhook notification error",
                        level: :error,
                        webhook_url: account.webhook_url,
                        error: e.message)
      # Don't re-raise webhook errors
    end
  end
  
  def build_notification_message(alert, issues)
    website_name = alert.website.name
    critical_issues = issues.select { |issue| issue['severity'] == 'critical' }
    
    if critical_issues.size == 1
      issue = critical_issues.first
      "#{website_name} has a critical #{issue['metric']} issue: #{issue['description']}"
    else
      "#{website_name} has #{critical_issues.size} critical performance issues affecting user experience"
    end
  end
  
  def broadcast_notification_to_user(user, notification)
    # Broadcast real-time notification using Hotwire
    ActionCable.server.broadcast(
      "notifications:#{user.id}",
      {
        type: 'new_notification',
        notification: notification.to_json
      }
    )
  end
end