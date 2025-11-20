-- Sample Data Generation for SaaS Project Management App
-- This script generates realistic test data for analytics demonstration

-- Set random seed for reproducible results
SELECT setseed(0.5);

-- Generate sample users (1000 users over the past 12 months)
INSERT INTO users (email, created_at, activated_at, last_login_at, status, signup_channel, country_code, utm_source, utm_medium, utm_campaign)
SELECT 
    'user' || generate_series || '@example.com',
    -- Random signup dates over past 12 months
    CURRENT_TIMESTAMP - INTERVAL '12 months' + (random() * INTERVAL '12 months'),
    -- 80% of users get activated within 7 days
    CASE 
        WHEN random() < 0.8 THEN 
            CURRENT_TIMESTAMP - INTERVAL '12 months' + (random() * INTERVAL '12 months') + (random() * INTERVAL '7 days')
        ELSE NULL
    END,
    -- Last login between 1-30 days ago for active users
    CASE 
        WHEN random() < 0.1 THEN NULL -- 10% never logged in again
        ELSE CURRENT_TIMESTAMP - (random() * INTERVAL '30 days')
    END,
    -- User status distribution
    CASE 
        WHEN random() < 0.15 THEN 'churned'::user_status
        WHEN random() < 0.05 THEN 'inactive'::user_status
        ELSE 'active'::user_status
    END,
    -- Signup channel distribution
    CASE 
        WHEN random() < 0.3 THEN 'organic'::signup_channel
        WHEN random() < 0.5 THEN 'google_ads'::signup_channel
        WHEN random() < 0.65 THEN 'content'::signup_channel
        WHEN random() < 0.75 THEN 'referral'::signup_channel
        WHEN random() < 0.85 THEN 'facebook_ads'::signup_channel
        WHEN random() < 0.95 THEN 'email_campaign'::signup_channel
        ELSE 'direct'::signup_channel
    END,
    -- Country distribution (simplified)
    CASE 
        WHEN random() < 0.6 THEN 'US'
        WHEN random() < 0.75 THEN 'CA'
        WHEN random() < 0.85 THEN 'GB'
        WHEN random() < 0.9 THEN 'DE'
        WHEN random() < 0.95 THEN 'AU'
        ELSE 'FR'
    END,
    -- UTM source
    CASE 
        WHEN random() < 0.4 THEN 'google'
        WHEN random() < 0.6 THEN 'facebook'
        WHEN random() < 0.75 THEN 'twitter'
        WHEN random() < 0.85 THEN 'linkedin'
        ELSE 'blog'
    END,
    -- UTM medium
    CASE 
        WHEN random() < 0.5 THEN 'cpc'
        WHEN random() < 0.7 THEN 'social'
        WHEN random() < 0.85 THEN 'email'
        ELSE 'organic'
    END,
    -- UTM campaign
    'campaign_' || (random() * 10)::INT
FROM generate_series(1, 1000);

-- Create subscriptions for users (realistic conversion funnel)
-- Start everyone on free plan
INSERT INTO subscriptions (user_id, plan_id, status, billing_cycle, started_at, mrr)
SELECT 
    u.id,
    1, -- Free plan
    'active'::subscription_status,
    'monthly'::billing_cycle,
    u.created_at,
    0
FROM users u;

-- Upgrade some free users to paid plans (15% conversion rate)
WITH paid_upgrades AS (
    SELECT 
        u.id as user_id,
        u.created_at,
        -- Plan selection (Basic vs Premium)
        CASE 
            WHEN random() < 0.7 THEN 2 -- 70% choose Basic
            ELSE 3 -- 30% choose Premium
        END as plan_id,
        -- Billing cycle preference
        CASE 
            WHEN random() < 0.3 THEN 'annual'::billing_cycle
            ELSE 'monthly'::billing_cycle
        END as billing_cycle,
        -- Upgrade timing (within 30 days of signup for most)
        u.created_at + (random() * INTERVAL '30 days') as upgrade_date
    FROM users u
    WHERE random() < 0.15 -- 15% upgrade rate
    AND u.status != 'churned'::user_status
)
INSERT INTO subscriptions (user_id, plan_id, status, billing_cycle, started_at, mrr)
SELECT 
    pu.user_id,
    pu.plan_id,
    'active'::subscription_status,
    pu.billing_cycle,
    pu.upgrade_date,
    CASE 
        WHEN pu.plan_id = 2 AND pu.billing_cycle = 'monthly'::billing_cycle THEN 9.99
        WHEN pu.plan_id = 2 AND pu.billing_cycle = 'annual'::billing_cycle THEN 99.90
        WHEN pu.plan_id = 3 AND pu.billing_cycle = 'monthly'::billing_cycle THEN 19.99
        WHEN pu.plan_id = 3 AND pu.billing_cycle = 'annual'::billing_cycle THEN 199.90
    END
FROM paid_upgrades pu;

-- End free subscriptions for users who upgraded
UPDATE subscriptions 
SET status = 'cancelled'::subscription_status, ended_at = s2.started_at
FROM subscriptions s2 
WHERE subscriptions.user_id = s2.user_id 
AND subscriptions.plan_id = 1 
AND s2.plan_id != 1
AND subscriptions.id != s2.id;

-- Create some churn (cancel some paid subscriptions)
UPDATE subscriptions 
SET status = 'cancelled'::subscription_status, 
    ended_at = started_at + (random() * INTERVAL '6 months'),
    cancelled_at = started_at + (random() * INTERVAL '6 months')
WHERE plan_id != 1 
AND random() < 0.25; -- 25% churn rate

-- Generate projects (activated users create projects)
INSERT INTO projects (user_id, name, created_at, completed_at, is_active)
SELECT 
    u.id,
    'Project ' || project_num,
    u.activated_at + (random() * INTERVAL '3 months'),
    -- 30% of projects get completed
    CASE 
        WHEN random() < 0.3 THEN 
            u.activated_at + (random() * INTERVAL '6 months')
        ELSE NULL
    END,
    random() > 0.1 -- 90% active
FROM users u
CROSS JOIN generate_series(1, 3) project_num
WHERE u.activated_at IS NOT NULL
AND random() < 0.8; -- Not all users create projects

-- Generate tasks
INSERT INTO tasks (project_id, user_id, title, created_at, completed_at, is_completed)
SELECT 
    p.id,
    p.user_id,
    'Task ' || task_num || ' for ' || p.name,
    p.created_at + (random() * INTERVAL '30 days'),
    -- 60% of tasks get completed
    CASE 
        WHEN random() < 0.6 THEN 
            p.created_at + (random() * INTERVAL '60 days')
        ELSE NULL
    END,
    random() < 0.6
FROM projects p
CROSS JOIN generate_series(1, 8) task_num
WHERE random() < 0.7; -- Not every project gets all tasks

-- Generate team memberships (collaboration)
INSERT INTO team_memberships (inviter_user_id, invited_user_id, project_id, invited_at, accepted_at)
SELECT DISTINCT
    p.user_id,
    u2.id,
    p.id,
    p.created_at + (random() * INTERVAL '14 days'),
    -- 70% acceptance rate
    CASE 
        WHEN random() < 0.7 THEN 
            p.created_at + (random() * INTERVAL '21 days')
        ELSE NULL
    END
FROM projects p
JOIN users u2 ON u2.id != p.user_id
WHERE random() < 0.2 -- 20% of projects have team collaboration
AND u2.status = 'active'::user_status
LIMIT 500; -- Limit to reasonable number

-- Generate revenue events for paid subscriptions
INSERT INTO revenue_events (user_id, subscription_id, amount, event_type, occurred_at)
SELECT 
    s.user_id,
    s.id,
    s.mrr,
    'payment',
    -- Generate monthly payments
    s.started_at + (interval_month || ' months')::INTERVAL
FROM subscriptions s
CROSS JOIN generate_series(0, 11) interval_month
WHERE s.plan_id != 1 -- Not free plan
AND s.status = 'active'::subscription_status
AND s.started_at + (interval_month || ' months')::INTERVAL <= CURRENT_TIMESTAMP
AND (s.ended_at IS NULL OR s.started_at + (interval_month || ' months')::INTERVAL <= s.ended_at);

-- Generate user activity events
INSERT INTO user_activities (user_id, activity_type, occurred_at)
SELECT 
    u.id,
    activity_types.activity,
    u.created_at + (random() * INTERVAL '30 days')
FROM users u
CROSS JOIN (
    VALUES 
        ('login'),
        ('project_created'), 
        ('task_created'),
        ('team_invite_sent'),
        ('profile_updated'),
        ('settings_changed')
) AS activity_types(activity)
WHERE u.activated_at IS NOT NULL
AND random() < 0.4; -- Not all users do all activities

-- Generate funnel events
INSERT INTO funnel_events (user_id, event_name, occurred_at)
SELECT u.id, 'signup', u.created_at FROM users u;

INSERT INTO funnel_events (user_id, event_name, occurred_at)
SELECT u.id, 'onboarding_completed', u.activated_at 
FROM users u 
WHERE u.activated_at IS NOT NULL;

INSERT INTO funnel_events (user_id, event_name, occurred_at)
SELECT DISTINCT p.user_id, 'first_project_created', MIN(p.created_at)
FROM projects p 
GROUP BY p.user_id;

INSERT INTO funnel_events (user_id, event_name, occurred_at)
SELECT s.user_id, 'subscription_created', s.started_at
FROM subscriptions s 
WHERE s.plan_id != 1;

-- Update user status based on activity
UPDATE users 
SET status = 'churned'::user_status
WHERE last_login_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
AND status = 'active'::user_status;

UPDATE users 
SET status = 'inactive'::user_status
WHERE last_login_at < CURRENT_TIMESTAMP - INTERVAL '30 days'
AND last_login_at >= CURRENT_TIMESTAMP - INTERVAL '90 days'
AND status = 'active'::user_status;

-- Create some plan upgrades/downgrades
WITH plan_changes AS (
    SELECT 
        s.user_id,
        s.id as old_subscription_id,
        CASE 
            WHEN s.plan_id = 2 AND random() < 0.1 THEN 3 -- Basic to Premium (10%)
            WHEN s.plan_id = 3 AND random() < 0.05 THEN 2 -- Premium to Basic (5%)
            ELSE s.plan_id
        END as new_plan_id,
        s.started_at + (random() * INTERVAL '4 months') as change_date
    FROM subscriptions s 
    WHERE s.plan_id IN (2, 3) 
    AND s.status = 'active'
    AND random() < 0.15 -- 15% of paid users change plans
)
INSERT INTO subscriptions (user_id, plan_id, status, billing_cycle, started_at, mrr)
SELECT 
    pc.user_id,
    pc.new_plan_id,
    'active',
    'monthly',
    pc.change_date,
    CASE 
        WHEN pc.new_plan_id = 2 THEN 9.99
        WHEN pc.new_plan_id = 3 THEN 19.99
    END
FROM plan_changes pc
WHERE pc.new_plan_id != (
    SELECT plan_id FROM subscriptions WHERE id = pc.old_subscription_id
);

-- End old subscriptions for plan changes
UPDATE subscriptions 
SET status = 'cancelled', ended_at = s2.started_at
FROM subscriptions s2 
WHERE subscriptions.user_id = s2.user_id 
AND subscriptions.started_at < s2.started_at
AND subscriptions.plan_id != 1
AND subscriptions.status = 'active'
AND s2.plan_id != 1
AND subscriptions.id != s2.id;