# 🚀 Quick Start Guide

Get up and running with SaaS analytics in 5 minutes!

## Option 1: One-Command Setup (Recommended)

```bash
# Clone and setup everything
git clone <your-repo-url>
cd postgres_demo
./setup_database.sh
```

This will:
- ✅ Create PostgreSQL database with realistic sample data
- ✅ Generate 1000+ users with 12 months of history  
- ✅ Set up subscription plans (Free/Basic/Premium)
- ✅ Create schema diagram visualization

## Option 2: Docker Setup (Isolated)

```bash
# Start PostgreSQL in Docker
docker-compose up -d

# Database ready at localhost:5432
# Optional: pgAdmin web interface at localhost:8080
```

## Option 3: Manual Setup

```bash
# 1. Create database
createdb saas_analytics_demo

# 2. Load schema
psql -d saas_analytics_demo -f schema.sql

# 3. Import sample data  
psql -d saas_analytics_demo -f sample_data.sql
```

## 🔍 Start Analyzing

### Connect to Database
```bash
psql -U saas_user -d saas_analytics_demo
```

### Run Sample Queries
```sql
-- Current MRR by plan
SELECT 
    p.name as plan,
    SUM(s.mrr) as monthly_recurring_revenue
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
WHERE s.status = 'active'
GROUP BY p.name;

-- Free to paid conversion rate
SELECT 
    COUNT(CASE WHEN s.plan_id = 1 THEN 1 END) as free_users,
    COUNT(CASE WHEN s.plan_id != 1 THEN 1 END) as paid_users,
    ROUND(COUNT(CASE WHEN s.plan_id != 1 THEN 1 END) * 100.0 / COUNT(*), 2) as conversion_rate_pct
FROM subscriptions s
WHERE s.status = 'active';
```

### Use Pre-built Analytics
```bash
# All analytics queries
psql -d saas_analytics_demo -f analytics_queries.sql

# Quick dashboard
python3 quick_dashboard.py
```

## 📊 Key Files

| File | Purpose |
|------|---------|
| `schema.sql` | Complete database schema |
| `analytics_queries.sql` | 50+ analytical SQL queries |
| `sample_data.sql` | Realistic sample data generation |
| `schema_diagram.png` | Visual database structure |
| `key_questions.md` | All analytics questions covered |

## 🎯 Common Use Cases

### Revenue Analysis
```sql
-- Monthly revenue trend
SELECT 
    DATE_TRUNC('month', re.occurred_at) as month,
    SUM(re.amount) as revenue
FROM revenue_events re
WHERE re.event_type = 'payment'
GROUP BY month
ORDER BY month;
```

### Churn Analysis  
```sql
-- Churn rate by plan
SELECT 
    p.name,
    COUNT(CASE WHEN s.status = 'cancelled' THEN 1 END) * 100.0 / COUNT(*) as churn_rate_pct
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
WHERE s.plan_id != 1
GROUP BY p.name;
```

### Funnel Analysis
```sql
-- Conversion funnel
SELECT 
    COUNT(CASE WHEN fe.event_name = 'signup' THEN 1 END) as signups,
    COUNT(CASE WHEN fe.event_name = 'onboarding_completed' THEN 1 END) as activated,
    COUNT(CASE WHEN fe.event_name = 'subscription_created' THEN 1 END) as paid
FROM funnel_events fe;
```

## 🔧 Troubleshooting

**Database connection failed?**
```bash
# Check if PostgreSQL is running
pg_isready

# Restart if needed
sudo systemctl restart postgresql
```

**Need to reset data?**
```bash
./setup_database.sh --reset
```

**Want to customize plans?**
Edit the plans in `schema.sql` and re-run setup.

## 📚 Next Steps

1. **Explore**: Browse `analytics_queries.sql` for more examples
2. **Customize**: Modify `sample_data.sql` for your scenarios  
3. **Extend**: Add your own tables and metrics
4. **Visualize**: Connect to Tableau, PowerBI, or Grafana
5. **Production**: Replace sample data with real customer data

---

**Need help?** Check the full `README.md` or open an issue!