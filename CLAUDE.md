# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

- `TDD` - Test-Driven Development
- `RSpec` - Ruby testing framework
- `FactoryBot` - Factory creation for testing
- `Capybara` - Feature testing
- `Webpacker` - JavaScript bundling
- `TailwindCSS` - Utility-first CSS framework
- `ESBuild` - JavaScript bundling
- `Puma` - Web server
- `Kamal` - Modern Rails deployment tooling


### Setup & Installation

- `bin/setup` - Full project setup (installs dependencies, prepares database, starts server)
- `bin/setup --skip-server` - Setup without starting the development server
- `bundle install` - Install Ruby dependencies only

### Development Server
- `bin/dev` - Start development server with Foreman (Rails server + Tailwind CSS watch)
- `bin/rails server` - Start Rails server only
- `bin/rails tailwindcss:watch` - Watch and compile Tailwind CSS

### Testing
- `bin/rails test` - Run all unit/integration tests
- `bin/rails test:system` - Run system tests (requires Chrome/Chromium)
- `bin/rails db:test:prepare` - Prepare test database

### Code Quality & Security
- `bin/rubocop` - Run RuboCop linter (uses rails-omakase style)
- `bin/rubocop -a` - Auto-correct RuboCop violations
- `bin/brakeman` - Security vulnerability scanning
- `bin/importmap audit` - JavaScript dependency security audit

### Database
- `bin/rails db:prepare` - Create and migrate database
- `bin/rails db:migrate` - Run pending migrations
- `bin/rails db:rollback` - Rollback last migration
- `bin/rails db:reset` - Drop, create, migrate, and seed database
- `bin/rails console` - Open Rails console

### Background Jobs
- `bin/jobs` - Run Solid Queue job worker
- `bin/rails solid_queue:start` - Start Solid Queue supervisor

### Deployment
- `bin/kamal setup` - Initial Kamal deployment setup
- `bin/kamal deploy` - Deploy application with Kamal
- `bin/kamal console` - Remote Rails console
- `bin/kamal shell` - Remote shell access

## Architecture Overview

### Rails 8.0 Modern Stack
This is a Rails 8.0 application using the new "no PaaS required" philosophy with:

**Solid Stack (Database-backed solutions):**
- **Solid Queue** - Database-backed background jobs (replaces Redis/Sidekiq)
- **Solid Cache** - Database-backed caching (replaces Redis cache)
- **Solid Cable** - Database-backed WebSocket connections (replaces Redis ActionCable)

**Modern Asset Pipeline:**
- **Propshaft** - Simplified asset pipeline (replaces Sprockets)
- **Importmap** - JavaScript import maps (no bundling required)
- **Tailwind CSS** - Utility-first CSS framework

**Frontend Technologies:**
- **Hotwire** - Stimulus (JavaScript framework) + Turbo (SPA-like navigation)
- **Progressive Web App** - PWA capabilities with service worker

### Database Configuration
- **Development/Test:** PostgreSQL with single database
- **Production:** Multi-database setup with separate databases for:
  - Primary application data
  - Solid Cache storage
  - Solid Queue jobs
  - Solid Cable connections

### Deployment Architecture
- **Kamal 2** - Modern deployment tool with zero-downtime deployments
- **Thruster** - HTTP/2 proxy with asset acceleration and compression
- **Docker** - Containerized deployment
- **SSL** - Automatic Let's Encrypt SSL certificates

### Application Structure
- Standard Rails MVC architecture
- PostgreSQL as primary database
- Background jobs processed in-process with Solid Queue
- Real-time features via Solid Cable WebSockets
- API-ready with jbuilder for JSON responses

### Key Features
- Built-in authentication generators available (`bin/rails generate authentication`)
- PWA-ready with manifest and service worker
- Security-first with Brakeman scanning and CSP headers
- Modern Ruby 3.4.3 with Rails 8.0 features
- GitHub Actions CI/CD with comprehensive testing pipeline

### Development Workflow
1. Changes are tested locally with `bin/dev`
2. Code quality checked with RuboCop and Brakeman
3. Tests run with both unit and system testing
4. Deployment via Kamal to production servers
5. Monitoring and debugging through Rails console and logs