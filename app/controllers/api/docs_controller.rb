module Api
  class DocsController < ActionController::Base
    layout 'application'
    
    def index
      @api_documentation = {
        version: 'v1',
        base_url: "#{request.base_url}/api/v1",
        authentication: {
          method: 'Bearer Token',
          header: 'Authorization',
          format: 'Bearer YOUR_API_TOKEN'
        },
        endpoints: [
          {
            path: '/websites',
            method: 'GET',
            description: 'List all websites for the authenticated account',
            parameters: {
              page: 'integer (optional) - Page number for pagination',
              per_page: 'integer (optional) - Items per page (default: 20)'
            }
          },
          {
            path: '/websites/:id',
            method: 'GET',
            description: 'Get details of a specific website',
            parameters: {
              id: 'integer (required) - Website ID'
            }
          },
          {
            path: '/websites/:website_id/audit_reports',
            method: 'GET',
            description: 'List all audit reports for a website',
            parameters: {
              website_id: 'integer (required) - Website ID',
              page: 'integer (optional) - Page number for pagination'
            }
          },
          {
            path: '/websites/:website_id/audit_reports',
            method: 'POST',
            description: 'Create a new audit report for a website',
            parameters: {
              website_id: 'integer (required) - Website ID'
            },
            body: {
              url: 'string (optional) - URL to audit (defaults to website URL)',
              audit_type: 'string (optional) - Type of audit: performance, seo, accessibility'
            }
          },
          {
            path: '/websites/:website_id/audit_reports/:id',
            method: 'GET',
            description: 'Get details of a specific audit report',
            parameters: {
              website_id: 'integer (required) - Website ID',
              id: 'integer (required) - Audit Report ID'
            }
          },
          {
            path: '/websites/:website_id/performance_metrics',
            method: 'GET',
            description: 'Get performance metrics for a website',
            parameters: {
              website_id: 'integer (required) - Website ID',
              start_date: 'date (optional) - Start date for metrics',
              end_date: 'date (optional) - End date for metrics'
            }
          },
          {
            path: '/accounts/:id',
            method: 'GET',
            description: 'Get account details',
            parameters: {
              id: 'integer (required) - Account ID'
            }
          },
          {
            path: '/accounts/:id/usage_stats',
            method: 'GET',
            description: 'Get usage statistics for an account',
            parameters: {
              id: 'integer (required) - Account ID'
            }
          },
          {
            path: '/webhooks/audit_completed',
            method: 'POST',
            description: 'Webhook endpoint for audit completion notifications',
            body: {
              audit_report_id: 'integer (required) - Completed audit report ID',
              website_id: 'integer (required) - Website ID',
              status: 'string (required) - Completion status',
              scores: 'object (required) - Audit scores'
            }
          },
          {
            path: '/webhooks/performance_alert',
            method: 'POST',
            description: 'Webhook endpoint for performance alert notifications',
            body: {
              website_id: 'integer (required) - Website ID',
              alert_type: 'string (required) - Type of alert',
              severity: 'string (required) - Alert severity',
              details: 'object (required) - Alert details'
            }
          }
        ],
        response_formats: {
          success: {
            status: '200 OK',
            body: {
              data: 'object or array - Response data',
              meta: 'object (optional) - Metadata like pagination info'
            }
          },
          error: {
            status: '4xx or 5xx',
            body: {
              error: 'string - Error message',
              details: 'object (optional) - Additional error details'
            }
          }
        },
        rate_limiting: {
          limit: '1000 requests per hour',
          header: 'X-RateLimit-Remaining'
        }
      }
      
      respond_to do |format|
        format.html { render :index }
        format.json { render json: @api_documentation }
      end
    end
  end
end