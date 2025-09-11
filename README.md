# SpeedBoost - Website Performance Optimization SaaS

**QuickFixPro** (SpeedBoost) is a comprehensive, production-ready Website Speed Optimization SaaS platform built with Ruby on Rails 8. It provides real-time performance monitoring, automated audits, and actionable optimization recommendations to help businesses improve their website performance and Core Web Vitals scores.

## 🚀 Features

### Core Functionality
- **Multi-Tenant SaaS Architecture** - Complete account isolation with subscription-based access
- **Real-Time Performance Monitoring** - Continuous tracking of Core Web Vitals and performance metrics
- **Automated Performance Audits** - Scheduled and on-demand website performance analysis
- **Actionable Recommendations** - AI-powered optimization suggestions with implementation guides
- **Live Dashboard** - Real-time analytics with Hotwire-powered updates
- **Subscription Management** - Tiered plans with usage tracking and billing integration

### Performance Metrics Tracked
- **Core Web Vitals**: LCP, FID, CLS, TTFB, INP
- **Performance Metrics**: Page load time, Time to Interactive, Speed Index
- **Resource Analysis**: Image optimization, JavaScript/CSS minification
- **SEO Factors**: Meta tags, structured data, accessibility scores
- **Mobile Performance**: Mobile-first indexing readiness and performance

### Business Features
- **Multi-User Teams** - Role-based access control (Owner, Admin, Member, Viewer)
- **Usage-Based Billing** - Automatic usage tracking with plan limit enforcement
- **API Access** - RESTful API for integrations and external tools
- **Webhook Support** - Real-time notifications for audit completion and alerts
- **White-Label Ready** - Customizable branding and domain support

## 🛠 Technology Stack

### Backend
- **Ruby on Rails 8.0+** - Latest Rails with Solid Stack integration
- **PostgreSQL 15+** - Primary database with UUID primary keys and JSONB support
- **Solid Queue** - Background job processing (Redis-free)
- **Solid Cache** - High-capacity disk-based caching
- **Solid Cable** - WebSocket connections for real-time updates

### Frontend
- **Hotwire (Turbo + Stimulus)** - Modern Rails frontend with minimal JavaScript
- **TailwindCSS 3.x** - Utility-first CSS framework
- **ViewComponent** - Component-based view architecture
- **ActionCable** - Real-time WebSocket connections

### DevOps & Infrastructure
- **Docker & Docker Compose** - Containerized development and deployment
- **GitHub Actions** - CI/CD pipeline automation
- **Kamal 2** - Modern Rails deployment tooling
- **Thruster** - High-performance asset serving

### Performance & Monitoring Tools
- **Ferrum** - Chrome DevTools API integration for performance analysis
- **HTTParty** - HTTP client for external API integrations
- **Lighthouse CI** - Automated performance auditing
- **WebPageTest API** - Advanced performance testing integration

## 📊 Application Architecture

### Multi-Tenant Data Model

```ruby
# Core Models Hierarchy
Account (Tenant Root)
├── Users (Team Members with Roles)
├── Websites (Monitored Sites)
├── Subscription (Plan & Usage Tracking)
└── AuditReports
    ├── PerformanceMetrics (Core Web Vitals)
    └── OptimizationRecommendations (Action Items)
```

### Database Schema

#### Accounts (Multi-Tenant Root)
```sql
accounts:
  - id: uuid (primary key)
  - name: string
  - domain: string
  - status: enum (trial, active, suspended, cancelled)
  - settings: jsonb
  - created_at, updated_at: timestamp
```

#### Users (Team Management)
```sql
users:
  - id: uuid (primary key)
  - account_id: uuid (foreign key)
  - email: string (unique per account)
  - role: enum (owner, admin, member, viewer)
  - first_name, last_name: string
  - devise fields (authentication)
```

#### Websites (Monitored Properties)
```sql
websites:
  - id: uuid (primary key)
  - account_id: uuid (foreign key)
  - name: string
  - url: string
  - status: enum (active, paused, archived)
  - monitoring_frequency: enum (manual, daily, weekly, monthly)
  - settings: jsonb (monitoring configuration)
  - performance_score: decimal
```

#### Subscription Management
```sql
subscriptions:
  - id: uuid (primary key)
  - account_id: uuid (foreign key)
  - plan_name: string (starter, professional, enterprise)
  - status: enum (trial, active, past_due, cancelled, expired)
  - monthly_price: decimal
  - usage_limits: jsonb
  - current_usage: jsonb
  - trial_ends_at: timestamp
```

### Performance Analysis Models

#### Audit Reports
```sql
audit_reports:
  - id: uuid (primary key)
  - website_id: uuid (foreign key)
  - status: enum (pending, running, completed, failed, cancelled)
  - overall_score: decimal (0-100)
  - raw_results: jsonb (full Lighthouse data)
  - summary_data: jsonb (processed insights)
  - started_at, completed_at: timestamp
```

#### Performance Metrics
```sql
performance_metrics:
  - id: uuid (primary key)
  - audit_report_id: uuid (foreign key)
  - metric_type: string (lcp, fid, cls, ttfb, etc.)
  - value: decimal
  - threshold_status: enum (good, needs_improvement, poor)
  - previous_value: decimal
```

## 🏗 Application Structure

### Controllers Architecture

```
app/controllers/
├── application_controller.rb     # Multi-tenant base with security
├── dashboard_controller.rb       # Real-time analytics dashboard
├── websites_controller.rb        # Website management CRUD
├── audit_reports_controller.rb   # Performance audit results
├── subscriptions_controller.rb   # Billing and plan management
└── api/
    └── v1/
        ├── websites_controller.rb
        ├── audit_reports_controller.rb
        └── webhooks_controller.rb
```

### Services Architecture

```
app/services/
├── performance_analyzer_service.rb    # Core performance analysis
├── lighthouse_runner_service.rb       # Chrome DevTools automation
├── recommendation_generator_service.rb # AI-powered suggestions
├── subscription_manager_service.rb    # Billing and usage tracking
└── notification_service.rb            # Email and webhook notifications
```

### Background Jobs

```
app/jobs/
├── performance_audit_job.rb          # Main audit orchestration
├── lighthouse_analysis_job.rb        # Performance data collection
├── recommendation_generation_job.rb   # Optimization suggestions
├── usage_tracking_job.rb             # Subscription usage updates
└── notification_job.rb               # Alert and notification delivery
```

## 🔒 Security Features

### Multi-Tenant Security
- **Account Isolation** - All data scoped to account with automatic filtering
- **Role-Based Access Control** - Granular permissions per user role
- **Usage Limit Enforcement** - Automatic blocking when limits exceeded
- **Data Encryption** - Sensitive data encrypted at rest and in transit

### Production Security Headers
```ruby
# Comprehensive security headers
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: [Configured for TailwindCSS and Hotwire]
Referrer-Policy: strict-origin-when-cross-origin
```

### Authentication & Authorization
- **Devise Integration** - Battle-tested authentication
- **Account-Scoped Sessions** - Multi-tenant session management
- **API Token Authentication** - Secure API access
- **Password Complexity** - Enforced strong passwords
- **Session Timeout** - Automatic security logout

## 💼 Subscription Plans

### Plan Tiers & Limits

| Feature | Starter | Professional | Enterprise |
|---------|---------|--------------|------------|
| **Websites** | 5 | 25 | Unlimited |
| **Monthly Audits** | 100 | 500 | Unlimited |
| **Team Members** | 2 | 10 | Unlimited |
| **API Requests** | 1,000 | 10,000 | Unlimited |
| **Historical Data** | 3 months | 12 months | Unlimited |
| **Support Level** | Email | Priority | Dedicated |
| **Monthly Price** | $29 | $99 | $299 |

### Usage Tracking & Enforcement
- **Real-Time Usage Monitoring** - Automatic tracking of all plan limits
- **Soft Limit Warnings** - Proactive notifications at 75% usage
- **Hard Limit Enforcement** - Automatic blocking at 100% usage
- **Grace Period Handling** - 7-day grace period for plan upgrades
- **Usage Analytics** - Detailed usage breakdowns and forecasting

## 🚀 Getting Started

### Prerequisites
- Ruby 3.2+ (preferably 3.3+)
- Rails 8.0+
- PostgreSQL 15+
- Node.js 18+ (for TailwindCSS)
- Chrome/Chromium (for Lighthouse audits)
- Redis (optional, for production scaling)

### Local Development Setup

1. **Clone and Setup**
```bash
git clone <repository-url>
cd QuickFixPro
bundle install
yarn install
```

2. **Database Setup**
```bash
# Create and migrate database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# Load sample data (optional)
bin/rails db:seed:sample_data
```

3. **Environment Configuration**
```bash
# Copy environment file
cp .env.example .env

# Required environment variables
CHROME_PATH=/usr/bin/google-chrome  # Chrome executable path
DATABASE_URL=postgresql://user:password@localhost/quickfixpro_development
REDIS_URL=redis://localhost:6379/0  # Optional for production
```

4. **Start Development Server**
```bash
# Start all services with Procfile.dev
bin/dev

# Or manually:
bin/rails server
bin/rails solid_queue:start
```

### Docker Development Setup

1. **Using Docker Compose**
```bash
# Build and start all services
docker-compose up --build

# Run database migrations
docker-compose exec web bin/rails db:migrate

# Create sample data
docker-compose exec web bin/rails db:seed
```

2. **Services Included**
- **Web** - Rails application server
- **Database** - PostgreSQL 15
- **Chrome** - Headless Chrome for Lighthouse
- **Redis** - For production-like caching (optional)

## 🔧 Configuration

### Environment Variables

#### Required
```bash
# Database
DATABASE_URL=postgresql://user:password@host:port/database

# Chrome/Lighthouse
CHROME_PATH=/usr/bin/google-chrome
CHROME_ARGS="--headless --disable-gpu --no-sandbox"

# Application
RAILS_MASTER_KEY=<your-master-key>
```

#### Optional Production
```bash
# Caching
REDIS_URL=redis://localhost:6379/0

# Email
SMTP_HOST=smtp.mailgun.org
SMTP_USERNAME=postmaster@yourdomain.com
SMTP_PASSWORD=<your-password>

# Monitoring
SENTRY_DSN=<your-sentry-dsn>
HONEYBADGER_API_KEY=<your-api-key>

# External Services
WEBPAGETEST_API_KEY=<your-api-key>
LIGHTHOUSE_CI_TOKEN=<your-token>
```

### Solid Queue Configuration

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue

# config/solid_queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "performance_audits"
      threads: 3
    - queues: "notifications"
      threads: 5
    - queues: "default"
      threads: 2
```

## 🧪 Testing

### Test Suite Structure
```
spec/
├── models/              # Model unit tests
├── controllers/         # Controller integration tests
├── services/           # Service object tests
├── jobs/               # Background job tests
├── requests/           # API endpoint tests
├── system/             # End-to-end browser tests
├── factories/          # Test data factories
└── support/            # Test helper modules
```

### Running Tests
```bash
# Full test suite
bundle exec rspec

# Specific test types
bundle exec rspec spec/models
bundle exec rspec spec/services
bundle exec rspec spec/system

# With coverage report
COVERAGE=true bundle exec rspec
```

### Test Configuration
- **RSpec** - Primary testing framework
- **FactoryBot** - Test data generation
- **WebMock** - HTTP request stubbing
- **Capybara** - Browser automation for system tests
- **SimpleCov** - Code coverage reporting
- **Database Cleaner** - Test database cleanup

## 🚀 Deployment

### Production Environment

#### Using Kamal 2 (Recommended)
```bash
# Initial deployment setup
kamal setup

# Deploy updates
kamal deploy

# Check deployment status
kamal app logs
kamal app details
```

#### Environment Requirements
- **Linux Server** - Ubuntu 20.04+ or similar
- **Docker** - For containerized deployment
- **PostgreSQL 15+** - Primary database
- **Chrome/Chromium** - For Lighthouse audits
- **SSL Certificate** - Let's Encrypt recommended

#### Production Configuration
```yaml
# config/deploy.yml
service: quickfixpro
image: quickfixpro
servers:
  web:
    - your-server-ip
  accessories:
    db:
      image: postgres:15
      env:
        POSTGRES_DB: quickfixpro_production
        POSTGRES_USER: quickfixpro
        POSTGRES_PASSWORD: <secure-password>
    chrome:
      image: browserless/chrome:latest
      port: 3000
```

### Performance Optimization

#### Database Optimization
```ruby
# Recommended PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

# Key indexes for performance
CREATE INDEX CONCURRENTLY idx_websites_account_status 
  ON websites (account_id, status);
CREATE INDEX CONCURRENTLY idx_audit_reports_website_completed 
  ON audit_reports (website_id, completed_at) 
  WHERE status = 'completed';
```

#### Caching Strategy
- **Solid Cache** - Primary caching layer
- **Action Caching** - Controller-level caching
- **Fragment Caching** - View partial caching
- **Russian Doll Caching** - Nested cache invalidation
- **CDN Integration** - CloudFlare/AWS CloudFront ready

## 📊 Monitoring & Observability

### Application Monitoring
- **Health Check Endpoint** - `/up` for load balancer monitoring
- **Performance Metrics** - Built-in Rails metrics
- **Error Tracking** - Sentry integration ready
- **Log Aggregation** - Structured JSON logging
- **Uptime Monitoring** - External monitoring integration points

### Business Metrics Dashboard
- **Account Growth** - User acquisition and churn tracking
- **Revenue Metrics** - MRR, ARPU, LTV calculations
- **Usage Analytics** - Feature adoption and engagement
- **Performance Benchmarks** - Industry comparison data
- **System Health** - Infrastructure and application metrics

## 🔌 API Documentation

### Authentication
```bash
# API Token authentication
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
     https://api.yourapp.com/api/v1/websites
```

### Core Endpoints

#### Websites Management
```bash
# List websites
GET /api/v1/websites

# Get website details
GET /api/v1/websites/{id}

# Run performance audit
POST /api/v1/websites/{id}/audit_reports
```

#### Performance Data
```bash
# Get audit reports
GET /api/v1/websites/{id}/audit_reports

# Get performance metrics
GET /api/v1/websites/{id}/performance_metrics

# Account usage statistics
GET /api/v1/accounts/usage_stats
```

### Webhook Events
```json
{
  "event": "audit.completed",
  "data": {
    "audit_report_id": "uuid",
    "website_id": "uuid",
    "overall_score": 85.5,
    "completed_at": "2024-01-15T10:30:00Z"
  }
}
```

## 🤝 Contributing

### Development Workflow
1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Write** tests for your changes
4. **Implement** your feature with tests passing
5. **Commit** your changes (`git commit -m 'Add amazing feature'`)
6. **Push** to your branch (`git push origin feature/amazing-feature`)
7. **Create** a Pull Request

### Code Standards
- **Rubocop** - Ruby style guide enforcement
- **RSpec** - Test-driven development required
- **Security** - Code security scanning with Brakeman
- **Documentation** - Inline documentation for complex methods
- **Performance** - Performance impact consideration for all changes

### Pull Request Requirements
- [ ] All tests passing (`bundle exec rspec`)
- [ ] Rubocop violations resolved (`bundle exec rubocop`)
- [ ] Security scan clean (`bundle exec brakeman`)
- [ ] Database migration safety verified
- [ ] Documentation updated (if needed)
- [ ] Performance impact assessed

## 📞 Support & Documentation

### Getting Help
- **GitHub Issues** - Bug reports and feature requests
- **Documentation** - Comprehensive guides in `/docs`
- **API Reference** - OpenAPI specification available
- **Community Forum** - Developer community discussions
- **Email Support** - Technical support for subscribers

### Documentation Resources
- **Setup Guide** - Detailed environment setup instructions
- **API Documentation** - Complete API reference with examples
- **Deployment Guide** - Production deployment best practices
- **Performance Optimization** - Advanced tuning recommendations
- **Security Guide** - Security hardening and best practices

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Rails Team** - For the excellent Rails 8 framework
- **Hotwire Team** - For modern Rails frontend capabilities
- **TailwindCSS** - For the utility-first CSS framework
- **Chrome DevTools Team** - For Lighthouse performance auditing
- **Community Contributors** - For feedback and contributions

---

**Built with ❤️ using Ruby on Rails 8 and modern web technologies.**

For the latest updates and detailed documentation, visit: [Documentation Site](https://docs.yourapp.com)
