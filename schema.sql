-- PostgreSQL Schema for SaaS Project Management App Analytics Demo
-- Supports three plans: Free, Basic, Premium

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enum types for better data integrity
CREATE TYPE plan_type AS ENUM ('free', 'basic', 'premium');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'paused', 'expired');
CREATE TYPE billing_cycle AS ENUM ('monthly', 'annual');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'churned');
CREATE TYPE signup_channel AS ENUM ('organic', 'google_ads', 'facebook_ads', 'referral', 'content', 'direct', 'email_campaign');

-- Users table - core user information
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    activated_at TIMESTAMP WITH TIME ZONE, -- When user completed onboarding/first value action
    last_login_at TIMESTAMP WITH TIME ZONE,
    status user_status DEFAULT 'active',
    signup_channel signup_channel DEFAULT 'direct',
    country_code VARCHAR(2), -- ISO country code
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    referred_by_user_id UUID REFERENCES users(id)
);

-- Plans table - subscription plan definitions
CREATE TABLE plans (
    id SERIAL PRIMARY KEY,
    name plan_type UNIQUE NOT NULL,
    price_monthly DECIMAL(10,2) NOT NULL DEFAULT 0,
    price_annual DECIMAL(10,2) NOT NULL DEFAULT 0,
    max_projects INTEGER,
    max_team_members INTEGER,
    features JSONB -- Store plan features as JSON
);

-- Subscriptions table - user subscription history
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    plan_id INTEGER NOT NULL REFERENCES plans(id),
    status subscription_status DEFAULT 'active',
    billing_cycle billing_cycle,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    mrr DECIMAL(10,2) NOT NULL DEFAULT 0, -- Monthly Recurring Revenue
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Projects table - user projects
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true
);

-- Tasks table - project tasks
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES projects(id),
    user_id UUID NOT NULL REFERENCES users(id),
    title VARCHAR(500) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    is_completed BOOLEAN DEFAULT false
);

-- Team memberships - for tracking team collaboration
CREATE TABLE team_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inviter_user_id UUID NOT NULL REFERENCES users(id),
    invited_user_id UUID NOT NULL REFERENCES users(id),
    project_id UUID NOT NULL REFERENCES projects(id),
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMP WITH TIME ZONE,
    role VARCHAR(50) DEFAULT 'member'
);

-- Revenue events - for tracking all revenue-related events
CREATE TABLE revenue_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id),
    amount DECIMAL(10,2) NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- 'payment', 'refund', 'upgrade', 'downgrade'
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    stripe_payment_id VARCHAR(255) -- External payment processor reference
);

-- User activity events - for engagement tracking
CREATE TABLE user_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    activity_type VARCHAR(100) NOT NULL, -- 'login', 'project_created', 'task_created', 'team_invite_sent', etc.
    metadata JSONB, -- Store additional activity data
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Funnel events - for conversion tracking
CREATE TABLE funnel_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    event_name VARCHAR(100) NOT NULL, -- 'signup', 'email_verified', 'onboarding_completed', 'first_project_created', 'payment_page_viewed', 'subscription_created'
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    session_id VARCHAR(255),
    page_url VARCHAR(500)
);

-- Indexes for performance
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_signup_channel ON users(signup_channel);
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_started_at ON subscriptions(started_at);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_projects_created_at ON projects(created_at);
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_created_at ON tasks(created_at);
CREATE INDEX idx_revenue_events_user_id ON revenue_events(user_id);
CREATE INDEX idx_revenue_events_occurred_at ON revenue_events(occurred_at);
CREATE INDEX idx_user_activities_user_id ON user_activities(user_id);
CREATE INDEX idx_user_activities_occurred_at ON user_activities(occurred_at);
CREATE INDEX idx_funnel_events_user_id ON funnel_events(user_id);
CREATE INDEX idx_funnel_events_event_name ON funnel_events(event_name);
CREATE INDEX idx_funnel_events_occurred_at ON funnel_events(occurred_at);

-- Insert default plans
INSERT INTO plans (name, price_monthly, price_annual, max_projects, max_team_members, features) VALUES
('free', 0, 0, 3, 1, '{"storage_gb": 1, "integrations": false, "priority_support": false}'),
('basic', 9.99, 99.90, 10, 5, '{"storage_gb": 10, "integrations": true, "priority_support": false}'),
('premium', 19.99, 199.90, -1, -1, '{"storage_gb": 100, "integrations": true, "priority_support": true, "advanced_analytics": true}');

-- Views for common queries
CREATE VIEW current_subscriptions AS
SELECT 
    s.*,
    u.email,
    u.created_at as user_created_at,
    p.name as plan_name,
    p.price_monthly,
    p.price_annual
FROM subscriptions s
JOIN users u ON s.user_id = u.id
JOIN plans p ON s.plan_id = p.id
WHERE s.status = 'active';

CREATE VIEW monthly_cohorts AS
SELECT 
    DATE_TRUNC('month', created_at) as cohort_month,
    COUNT(*) as cohort_size,
    signup_channel
FROM users 
GROUP BY DATE_TRUNC('month', created_at), signup_channel
ORDER BY cohort_month;

-- Function to calculate MRR for a given date
CREATE OR REPLACE FUNCTION calculate_mrr(target_date DATE DEFAULT CURRENT_DATE)
RETURNS DECIMAL(10,2) AS $$
BEGIN
    RETURN (
        SELECT COALESCE(SUM(
            CASE 
                WHEN s.billing_cycle = 'monthly' THEN s.mrr
                WHEN s.billing_cycle = 'annual' THEN s.mrr / 12
                ELSE s.mrr
            END
        ), 0)
        FROM subscriptions s
        WHERE s.status = 'active'
        AND s.started_at <= target_date
        AND (s.ended_at IS NULL OR s.ended_at > target_date)
    );
END;
$$ LANGUAGE plpgsql;