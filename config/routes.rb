Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  
  # Health check for monitoring
  get "up" => "rails/health#show", as: :rails_health_check

  # Root route - authenticated users go to dashboard
  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end
  
  unauthenticated do
    root to: "home#index", as: :unauthenticated_root
  end

  # Dashboard routes with real-time updates
  get 'dashboard', to: 'dashboard#index'
  get 'dashboard/metrics', to: 'dashboard#metrics'
  get 'dashboard/performance_overview', to: 'dashboard#performance_overview'
  get 'dashboard/usage_stats', to: 'dashboard#usage_stats'
  get 'dashboard/alerts', to: 'dashboard#alerts'
  
  # Turbo Frame endpoints for dashboard refresh
  get 'dashboard/stats', to: 'dashboard#stats', as: :dashboard_stats
  get 'dashboard/performance_chart', to: 'dashboard#performance_chart', as: :dashboard_performance_chart
  get 'dashboard/activity_feed', to: 'dashboard#activity_feed', as: :dashboard_activity_feed
  
  # Analytics routes
  get 'analytics', to: 'analytics#index'
  get 'analytics/performance', to: 'analytics#performance'
  get 'analytics/trends', to: 'analytics#trends'
  get 'analytics/comparisons', to: 'analytics#comparisons'
  get 'analytics/export', to: 'analytics#export'

  # Website management
  resources :websites do
    member do
      post :monitor
      get :audit_history
      # Modal actions
      get :quick_edit
      get :delete_confirmation
      patch :quick_update
      delete :quick_destroy
    end
    
    resources :audit_reports, only: [:index, :show] do
      member do
        get :performance_details
        get :optimization_suggestions
        get :export
      end
      
      collection do
        get :compare
      end
    end
    
    resources :monitoring_alerts, only: [:index, :show] do
      member do
        patch :acknowledge
        patch :resolve
        patch :dismiss
      end
      
      collection do
        patch :bulk_acknowledge
        patch :bulk_dismiss
      end
    end
    
    resources :performance_metrics, only: [:index, :show]
  end

  # Account management
  resource :account, only: [:show, :edit, :update] do
    member do
      get :billing
      get :usage
      get :team
    end
  end

  # Subscription management
  resources :subscriptions, only: [:show, :new, :create] do
    member do
      patch :upgrade
      patch :cancel
      patch :reactivate
    end
  end

  # User management (team members)
  resources :users, except: [:show] do
    member do
      patch :change_role
      delete :remove_from_account
    end
  end

  # API endpoints
  namespace :api do
    namespace :v1 do
      resources :websites, only: [:index, :show] do
        resources :audit_reports, only: [:index, :show, :create]
        resources :performance_metrics, only: [:index]
      end
      
      resources :accounts, only: [:show] do
        member do
          get :usage_stats
        end
      end
      
      # Webhook endpoints for external integrations
      post 'webhooks/audit_completed', to: 'webhooks#audit_completed'
      post 'webhooks/performance_alert', to: 'webhooks#performance_alert'
    end
  end

  # Account status pages
  get 'account/suspended', to: 'account_status#suspended'
  get 'account/cancelled', to: 'account_status#cancelled'
  
  # Billing and payment management
  get 'billing', to: 'billing#index'
  get 'billing/subscription', to: 'billing#subscription'
  get 'billing/payment_history', to: 'billing#payment_history'
  get 'billing/upgrade', to: 'billing#upgrade'
  post 'billing/process_upgrade', to: 'billing#process_upgrade'
  post 'billing/cancel_subscription', to: 'billing#cancel_subscription'

  # Static pages
  get 'about', to: 'pages#about'
  get 'pricing', to: 'pages#pricing'
  get 'features', to: 'pages#features'
  get 'contact', to: 'pages#contact'
  get 'privacy', to: 'pages#privacy'
  get 'terms', to: 'pages#terms'
  get 'security', to: 'pages#security'

  # SEO and crawlers
  get 'robots', to: 'robots#robots', defaults: { format: 'txt' }
  get 'robots.txt', to: 'robots#robots', defaults: { format: 'txt' }
  
  # Sitemaps
  get 'sitemap', to: 'sitemaps#index', defaults: { format: 'xml' }
  get 'sitemap.xml', to: 'sitemaps#index', defaults: { format: 'xml' }
  get 'sitemap_static', to: 'sitemaps#static', defaults: { format: 'xml' }
  get 'sitemap_marketing', to: 'sitemaps#marketing', defaults: { format: 'xml' }
  get 'sitemap_websites', to: 'sitemaps#websites', defaults: { format: 'xml' }
end
