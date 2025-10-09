-- Analytics Queries for SaaS Project Management App
-- These queries answer the key growth and marketing questions

-- =============================================================================
-- REVENUE & SALES ANALYTICS
-- =============================================================================

-- 1. Total volume of sales per plan (for various time periods)
-- Yesterday
SELECT 
    p.name as plan,
    COUNT(re.id) as transaction_count,
    SUM(re.amount) as total_revenue
FROM revenue_events re
JOIN subscriptions s ON re.subscription_id = s.id
JOIN plans p ON s.plan_id = p.id
WHERE re.occurred_at >= CURRENT_DATE - INTERVAL '1 day'
    AND re.occurred_at < CURRENT_DATE
    AND re.event_type = 'payment'
GROUP BY p.name
ORDER BY total_revenue DESC;

-- Last 7 days
SELECT 
    p.name as plan,
    COUNT(re.id) as transaction_count,
    SUM(re.amount) as total_revenue
FROM revenue_events re
JOIN subscriptions s ON re.subscription_id = s.id
JOIN plans p ON s.plan_id = p.id
WHERE re.occurred_at >= CURRENT_DATE - INTERVAL '7 days'
    AND re.event_type = 'payment'
GROUP BY p.name
ORDER BY total_revenue DESC;

-- Last 30 days
SELECT 
    p.name as plan,
    COUNT(re.id) as transaction_count,
    SUM(re.amount) as total_revenue
FROM revenue_events re
JOIN subscriptions s ON re.subscription_id = s.id
JOIN plans p ON s.plan_id = p.id
WHERE re.occurred_at >= CURRENT_DATE - INTERVAL '30 days'
    AND re.event_type = 'payment'
GROUP BY p.name
ORDER BY total_revenue DESC;

-- Monthly revenue trend by plan (last 12 months)
SELECT 
    DATE_TRUNC('month', re.occurred_at) as month,
    p.name as plan,
    COUNT(re.id) as transaction_count,
    SUM(re.amount) as total_revenue
FROM revenue_events re
JOIN subscriptions s ON re.subscription_id = s.id
JOIN plans p ON s.plan_id = p.id
WHERE re.occurred_at >= CURRENT_DATE - INTERVAL '12 months'
    AND re.event_type = 'payment'
GROUP BY DATE_TRUNC('month', re.occurred_at), p.name
ORDER BY month DESC, total_revenue DESC;

-- =============================================================================
-- MRR/ARR ANALYTICS
-- =============================================================================

-- 2. Current MRR by plan
SELECT 
    p.name as plan,
    COUNT(s.id) as active_subscriptions,
    SUM(CASE 
        WHEN s.billing_cycle = 'monthly' THEN s.mrr
        WHEN s.billing_cycle = 'annual' THEN s.mrr / 12
        ELSE s.mrr
    END) as monthly_recurring_revenue
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
WHERE s.status = 'active'
GROUP BY p.name
ORDER BY monthly_recurring_revenue DESC;

-- MRR growth rate by month
WITH monthly_mrr AS (
    SELECT 
        DATE_TRUNC('month', s.started_at) as month,
        p.name as plan,
        SUM(CASE 
            WHEN s.billing_cycle = 'monthly' THEN s.mrr
            WHEN s.billing_cycle = 'annual' THEN s.mrr / 12
            ELSE s.mrr
        END) as mrr
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.id
    WHERE s.status = 'active'
        AND s.started_at >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY DATE_TRUNC('month', s.started_at), p.name
),
mrr_with_previous AS (
    SELECT 
        month,
        plan,
        mrr,
        LAG(mrr) OVER (PARTITION BY plan ORDER BY month) as previous_mrr
    FROM monthly_mrr
)
SELECT 
    month,
    plan,
    mrr,
    previous_mrr,
    CASE 
        WHEN previous_mrr > 0 THEN 
            ROUND(((mrr - previous_mrr) / previous_mrr * 100)::NUMERIC, 2)
        ELSE NULL 
    END as growth_rate_percent
FROM mrr_with_previous
ORDER BY month DESC, plan;

-- ARR calculation
SELECT 
    p.name as plan,
    SUM(CASE 
        WHEN s.billing_cycle = 'monthly' THEN s.mrr * 12
        WHEN s.billing_cycle = 'annual' THEN s.mrr
        ELSE s.mrr * 12
    END) as annual_recurring_revenue
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
WHERE s.status = 'active'
GROUP BY p.name
ORDER BY annual_recurring_revenue DESC;

-- =============================================================================
-- CONVERSION & UPGRADE ANALYTICS
-- =============================================================================

-- 3. Free to paid conversion rates
WITH conversion_funnel AS (
    SELECT 
        COUNT(CASE WHEN free_sub.id IS NOT NULL THEN 1 END) as free_users,
        COUNT(CASE WHEN paid_sub.id IS NOT NULL THEN 1 END) as paid_users
    FROM users u
    LEFT JOIN subscriptions free_sub ON u.id = free_sub.user_id AND free_sub.plan_id = 1
    LEFT JOIN subscriptions paid_sub ON u.id = paid_sub.user_id AND paid_sub.plan_id != 1
)
SELECT 
    free_users,
    paid_users,
    ROUND((paid_users::NUMERIC / free_users * 100), 2) as conversion_rate_percent
FROM conversion_funnel;

-- Conversion by target plan
SELECT 
    p.name as target_plan,
    COUNT(s.id) as conversions,
    ROUND(COUNT(s.id) * 100.0 / SUM(COUNT(s.id)) OVER (), 2) as percent_of_conversions
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
WHERE s.plan_id != 1  -- Exclude free plan
GROUP BY p.name
ORDER BY conversions DESC;

-- 4. Time to upgrade from Free to Paid
WITH upgrade_times AS (
    SELECT 
        u.id as user_id,
        u.created_at as signup_date,
        MIN(s.started_at) as first_paid_subscription,
        EXTRACT(DAYS FROM MIN(s.started_at) - u.created_at) as days_to_upgrade
    FROM users u
    JOIN subscriptions s ON u.id = s.user_id
    WHERE s.plan_id != 1  -- Paid plans only
    GROUP BY u.id, u.created_at
)
SELECT 
    COUNT(*) as total_upgrades,
    ROUND(AVG(days_to_upgrade), 1) as avg_days_to_upgrade,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_upgrade) as median_days_to_upgrade,
    MIN(days_to_upgrade) as min_days_to_upgrade,
    MAX(days_to_upgrade) as max_days_to_upgrade
FROM upgrade_times;

-- Distribution of upgrade timing
WITH upgrade_times AS (
    SELECT 
        u.id as user_id,
        EXTRACT(DAYS FROM MIN(s.started_at) - u.created_at) as days_to_upgrade
    FROM users u
    JOIN subscriptions s ON u.id = s.user_id
    WHERE s.plan_id != 1
    GROUP BY u.id, u.created_at
)
SELECT 
    CASE 
        WHEN days_to_upgrade <= 1 THEN '0-1 days'
        WHEN days_to_upgrade <= 7 THEN '2-7 days'
        WHEN days_to_upgrade <= 30 THEN '8-30 days'
        WHEN days_to_upgrade <= 90 THEN '31-90 days'
        ELSE '90+ days'
    END as upgrade_timeframe,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM upgrade_times
GROUP BY 
    CASE 
        WHEN days_to_upgrade <= 1 THEN '0-1 days'
        WHEN days_to_upgrade <= 7 THEN '2-7 days'
        WHEN days_to_upgrade <= 30 THEN '8-30 days'
        WHEN days_to_upgrade <= 90 THEN '31-90 days'
        ELSE '90+ days'
    END
ORDER BY MIN(days_to_upgrade);

-- =============================================================================
-- RETENTION & CHURN ANALYTICS
-- =============================================================================

-- 5. Retention by plan (monthly cohorts)
WITH monthly_cohorts AS (
    SELECT 
        u.id as user_id,
        DATE_TRUNC('month', u.created_at) as cohort_month,
        p.name as plan
    FROM users u
    JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active'
    JOIN plans p ON s.plan_id = p.id
),
retention_data AS (
    SELECT 
        mc.cohort_month,
        mc.plan,
        COUNT(DISTINCT mc.user_id) as cohort_size,
        COUNT(DISTINCT CASE 
            WHEN u.last_login_at >= mc.cohort_month + INTERVAL '1 month' 
            THEN mc.user_id 
        END) as retained_1_month,
        COUNT(DISTINCT CASE 
            WHEN u.last_login_at >= mc.cohort_month + INTERVAL '3 months' 
            THEN mc.user_id 
        END) as retained_3_months,
        COUNT(DISTINCT CASE 
            WHEN u.last_login_at >= mc.cohort_month + INTERVAL '6 months' 
            THEN mc.user_id 
        END) as retained_6_months
    FROM monthly_cohorts mc
    JOIN users u ON mc.user_id = u.id
    WHERE mc.cohort_month >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY mc.cohort_month, mc.plan
)
SELECT 
    cohort_month,
    plan,
    cohort_size,
    ROUND(retained_1_month * 100.0 / cohort_size, 2) as retention_1_month_pct,
    ROUND(retained_3_months * 100.0 / cohort_size, 2) as retention_3_months_pct,
    ROUND(retained_6_months * 100.0 / cohort_size, 2) as retention_6_months_pct
FROM retention_data
ORDER BY cohort_month DESC, plan;

-- 6. Churn rate by plan
WITH churn_analysis AS (
    SELECT 
        p.name as plan,
        COUNT(s.id) as total_subscriptions,
        COUNT(CASE WHEN s.status = 'cancelled' THEN 1 END) as churned_subscriptions
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.id
    WHERE s.plan_id != 1  -- Exclude free plan
    GROUP BY p.name
)
SELECT 
    plan,
    total_subscriptions,
    churned_subscriptions,
    ROUND(churned_subscriptions * 100.0 / total_subscriptions, 2) as churn_rate_pct
FROM churn_analysis
ORDER BY churn_rate_pct DESC;

-- Monthly churn rate trend
WITH monthly_churn AS (
    SELECT 
        DATE_TRUNC('month', s.cancelled_at) as churn_month,
        p.name as plan,
        COUNT(s.id) as churned_count
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.id
    WHERE s.status = 'cancelled'
        AND s.cancelled_at >= CURRENT_DATE - INTERVAL '12 months'
        AND s.plan_id != 1
    GROUP BY DATE_TRUNC('month', s.cancelled_at), p.name
),
monthly_active AS (
    SELECT 
        DATE_TRUNC('month', date_series) as month,
        p.name as plan,
        COUNT(s.id) as active_count
    FROM generate_series(
        CURRENT_DATE - INTERVAL '12 months',
        CURRENT_DATE,
        INTERVAL '1 month'
    ) date_series
    CROSS JOIN plans p
    LEFT JOIN subscriptions s ON s.plan_id = p.id
        AND s.status = 'active'
        AND s.started_at <= date_series
        AND (s.ended_at IS NULL OR s.ended_at > date_series)
    WHERE p.name != 'free'
    GROUP BY DATE_TRUNC('month', date_series), p.name
)
SELECT 
    ma.month,
    ma.plan,
    ma.active_count,
    COALESCE(mc.churned_count, 0) as churned_count,
    CASE 
        WHEN ma.active_count > 0 THEN 
            ROUND(COALESCE(mc.churned_count, 0) * 100.0 / ma.active_count, 2)
        ELSE 0 
    END as monthly_churn_rate_pct
FROM monthly_active ma
LEFT JOIN monthly_churn mc ON ma.month = mc.churn_month AND ma.plan = mc.plan
ORDER BY ma.month DESC, ma.plan;

-- =============================================================================
-- ARPU & LTV ANALYTICS
-- =============================================================================

-- 7. Average Revenue Per User (ARPU) by plan
SELECT 
    p.name as plan,
    COUNT(DISTINCT s.user_id) as unique_users,
    SUM(re.amount) as total_revenue,
    ROUND(SUM(re.amount) / COUNT(DISTINCT s.user_id), 2) as arpu
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
JOIN revenue_events re ON s.id = re.subscription_id
WHERE re.event_type = 'payment'
    AND s.plan_id != 1  -- Exclude free plan
GROUP BY p.name
ORDER BY arpu DESC;

-- 8. Customer Lifetime Value (LTV) estimation by plan
WITH customer_metrics AS (
    SELECT 
        s.user_id,
        p.name as plan,
        SUM(re.amount) as total_revenue,
        COUNT(re.id) as payment_count,
        MIN(re.occurred_at) as first_payment,
        MAX(re.occurred_at) as last_payment,
        EXTRACT(DAYS FROM MAX(re.occurred_at) - MIN(re.occurred_at)) + 1 as customer_lifespan_days
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.id
    JOIN revenue_events re ON s.id = re.subscription_id
    WHERE re.event_type = 'payment'
        AND s.plan_id != 1
    GROUP BY s.user_id, p.name
)
SELECT 
    plan,
    COUNT(*) as customers,
    ROUND(AVG(total_revenue), 2) as avg_ltv,
    ROUND(AVG(customer_lifespan_days), 1) as avg_lifespan_days,
    ROUND(AVG(total_revenue / NULLIF(customer_lifespan_days, 0) * 30), 2) as avg_monthly_value
FROM customer_metrics
WHERE customer_lifespan_days > 0
GROUP BY plan
ORDER BY avg_ltv DESC;

-- =============================================================================
-- ENGAGEMENT & ACTIVATION ANALYTICS
-- =============================================================================

-- 9. Activation rate (users who create first project)
WITH activation_funnel AS (
    SELECT 
        COUNT(DISTINCT u.id) as total_signups,
        COUNT(DISTINCT CASE WHEN u.activated_at IS NOT NULL THEN u.id END) as activated_users,
        COUNT(DISTINCT p.user_id) as users_with_projects
    FROM users u
    LEFT JOIN projects p ON u.id = p.user_id
    WHERE u.created_at >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    total_signups,
    activated_users,
    users_with_projects,
    ROUND(activated_users * 100.0 / total_signups, 2) as activation_rate_pct,
    ROUND(users_with_projects * 100.0 / total_signups, 2) as project_creation_rate_pct
FROM activation_funnel;

-- 10. Engagement depth by plan
SELECT 
    p.name as plan,
    COUNT(DISTINCT s.user_id) as users,
    ROUND(AVG(user_stats.project_count), 1) as avg_projects_per_user,
    ROUND(AVG(user_stats.task_count), 1) as avg_tasks_per_user,
    ROUND(AVG(user_stats.team_invites), 1) as avg_team_invites_per_user
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
JOIN (
    SELECT 
        u.id as user_id,
        COUNT(DISTINCT pr.id) as project_count,
        COUNT(DISTINCT t.id) as task_count,
        COUNT(DISTINCT tm.id) as team_invites
    FROM users u
    LEFT JOIN projects pr ON u.id = pr.user_id
    LEFT JOIN tasks t ON u.id = t.user_id
    LEFT JOIN team_memberships tm ON u.id = tm.inviter_user_id
    GROUP BY u.id
) user_stats ON s.user_id = user_stats.user_id
WHERE s.status = 'active'
GROUP BY p.name
ORDER BY avg_tasks_per_user DESC;

-- =============================================================================
-- FUNNEL & CONVERSION ANALYTICS
-- =============================================================================

-- 11. Complete conversion funnel
WITH funnel_steps AS (
    SELECT 
        COUNT(DISTINCT CASE WHEN fe.event_name = 'signup' THEN fe.user_id END) as signups,
        COUNT(DISTINCT CASE WHEN fe.event_name = 'onboarding_completed' THEN fe.user_id END) as onboarding_completed,
        COUNT(DISTINCT CASE WHEN fe.event_name = 'first_project_created' THEN fe.user_id END) as first_project_created,
        COUNT(DISTINCT CASE WHEN fe.event_name = 'subscription_created' THEN fe.user_id END) as subscriptions_created
    FROM funnel_events fe
    WHERE fe.occurred_at >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    signups,
    onboarding_completed,
    first_project_created,
    subscriptions_created,
    ROUND(onboarding_completed * 100.0 / signups, 2) as onboarding_conversion_pct,
    ROUND(first_project_created * 100.0 / onboarding_completed, 2) as activation_conversion_pct,
    ROUND(subscriptions_created * 100.0 / first_project_created, 2) as paid_conversion_pct,
    ROUND(subscriptions_created * 100.0 / signups, 2) as overall_conversion_pct
FROM funnel_steps;

-- =============================================================================
-- PLAN UPGRADE/DOWNGRADE ANALYTICS
-- =============================================================================

-- 12. Plan changes analysis
WITH plan_changes AS (
    SELECT 
        s1.user_id,
        p1.name as from_plan,
        p2.name as to_plan,
        s1.ended_at as change_date,
        CASE 
            WHEN p1.price_monthly < p2.price_monthly THEN 'upgrade'
            WHEN p1.price_monthly > p2.price_monthly THEN 'downgrade'
            ELSE 'same_tier'
        END as change_type
    FROM subscriptions s1
    JOIN subscriptions s2 ON s1.user_id = s2.user_id
    JOIN plans p1 ON s1.plan_id = p1.id
    JOIN plans p2 ON s2.plan_id = p2.id
    WHERE s1.ended_at IS NOT NULL
        AND s2.started_at = s1.ended_at
        AND s1.plan_id != s2.plan_id
        AND s1.plan_id != 1 AND s2.plan_id != 1  -- Exclude free plan transitions
)
SELECT 
    change_type,
    from_plan,
    to_plan,
    COUNT(*) as change_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM plan_changes
WHERE change_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY change_type, from_plan, to_plan
ORDER BY change_count DESC;

-- =============================================================================
-- COHORT & CHANNEL ANALYTICS
-- =============================================================================

-- 13. Conversion by signup channel
SELECT 
    u.signup_channel,
    COUNT(u.id) as total_signups,
    COUNT(CASE WHEN u.activated_at IS NOT NULL THEN 1 END) as activated_users,
    COUNT(CASE WHEN s.plan_id != 1 THEN 1 END) as paid_conversions,
    ROUND(COUNT(CASE WHEN u.activated_at IS NOT NULL THEN 1 END) * 100.0 / COUNT(u.id), 2) as activation_rate_pct,
    ROUND(COUNT(CASE WHEN s.plan_id != 1 THEN 1 END) * 100.0 / COUNT(u.id), 2) as paid_conversion_rate_pct
FROM users u
LEFT JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active' AND s.plan_id != 1
WHERE u.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY u.signup_channel
ORDER BY paid_conversion_rate_pct DESC;

-- 14. Geographic performance
SELECT 
    u.country_code,
    COUNT(u.id) as total_users,
    COUNT(CASE WHEN s.plan_id != 1 THEN 1 END) as paid_users,
    SUM(CASE WHEN re.amount IS NOT NULL THEN re.amount ELSE 0 END) as total_revenue,
    ROUND(COUNT(CASE WHEN s.plan_id != 1 THEN 1 END) * 100.0 / COUNT(u.id), 2) as conversion_rate_pct,
    ROUND(AVG(CASE WHEN re.amount IS NOT NULL THEN re.amount END), 2) as avg_revenue_per_paid_user
FROM users u
LEFT JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active'
LEFT JOIN revenue_events re ON s.id = re.subscription_id AND re.event_type = 'payment'
GROUP BY u.country_code
HAVING COUNT(u.id) >= 10  -- Only show countries with significant user base
ORDER BY total_revenue DESC;

-- =============================================================================
-- SUMMARY DASHBOARD METRICS
-- =============================================================================

-- 15. Key metrics dashboard (current snapshot)
WITH current_metrics AS (
    SELECT 
        (SELECT COUNT(*) FROM users WHERE status = 'active') as active_users,
        (SELECT COUNT(*) FROM subscriptions WHERE status = 'active' AND plan_id != 1) as paid_subscribers,
        (SELECT calculate_mrr()) as current_mrr,
        (SELECT COUNT(*) FROM users WHERE created_at >= CURRENT_DATE - INTERVAL '30 days') as new_signups_30d,
        (SELECT COUNT(*) FROM subscriptions WHERE plan_id != 1 AND started_at >= CURRENT_DATE - INTERVAL '30 days') as new_paid_30d
)
SELECT 
    active_users,
    paid_subscribers,
    current_mrr,
    current_mrr * 12 as arr,
    new_signups_30d,
    new_paid_30d,
    ROUND(paid_subscribers * 100.0 / active_users, 2) as paid_conversion_rate_pct,
    ROUND(new_paid_30d * 100.0 / new_signups_30d, 2) as monthly_conversion_rate_pct
FROM current_metrics;