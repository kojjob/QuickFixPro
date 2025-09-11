class ApplicationJob < ActiveJob::Base
  # Rails 8 Solid Queue configuration
  queue_with_priority 10
  
  # Automatically retry jobs that encounter temporary failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 5
  retry_on Net::OpenTimeout, wait: 2.seconds, attempts: 10
  retry_on Net::ReadTimeout, wait: 2.seconds, attempts: 10
  retry_on Errno::ECONNREFUSED, wait: 5.seconds, attempts: 8
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 3
  
  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordInvalid
  discard_on ActiveRecord::RecordNotFound
  discard_on ArgumentError
  discard_on ActiveJob::DeserializationError
  
  # Set up job context for multi-tenant operations
  around_perform do |job, block|
    # Extract account_id from job arguments if present
    account_id = extract_account_id_from_arguments(job.arguments)
    
    if account_id
      account = Account.find_by(id: account_id)
      Current.account = account if account
    end
    
    block.call
  ensure
    Current.reset
  end
  
  private
  
  def extract_account_id_from_arguments(arguments)
    # Look for account_id in various argument formats
    arguments.each do |arg|
      case arg
      when Hash
        return arg[:account_id] || arg['account_id']
      when ActiveRecord::Base
        return arg.account_id if arg.respond_to?(:account_id)
      end
    end
    nil
  end
  
  # Logging helper for job execution
  def log_job_execution(message, level: :info, **additional_data)
    data = {
      job_class: self.class.name,
      job_id: job_id,
      queue_name: queue_name,
      account_id: Current.account&.id,
      **additional_data
    }
    
    Rails.logger.public_send(level, message, **data)
  end
end
