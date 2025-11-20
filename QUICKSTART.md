# 🚀 Quick Start Guide

Get up and running with SaaS analytics in **2 minutes**!

## ⚡ One-Command Setup (Recommended)

```bash
git clone <your-repo-url>
cd postgres_demo
docker compose up
```

**That's it!** 🎉

This single command starts:
- ✅ PostgreSQL with 1000+ sample users and 12 months of data
- ✅ Interactive Jupyter notebook with beautiful visualizations
- ✅ All necessary analytics libraries pre-installed

## 🌐 Access Your Analytics

After `docker compose up` finishes (takes ~30 seconds):

### 📊 Jupyter Notebook (Interactive Analytics)
Open your browser to: **http://localhost:8888**

You'll see an interactive notebook with:
- Real-time visualizations of all SaaS metrics
- MRR trends, churn analysis, conversion funnels
- Geographic and channel performance
- Customer lifetime value calculations

### 🗄️ PostgreSQL Database (Direct SQL Access)
```bash
psql -h localhost -p 5432 -U saas_user -d saas_analytics_demo
# Password: demo_password
```

### 🔧 pgAdmin (Optional Web Interface)
```bash
docker compose --profile pgadmin up
```
Then visit: **http://localhost:8080**

## 🎯 What You'll See

The Jupyter notebook includes:
1. **Key Metrics Dashboard** - Active users, MRR, conversion rates
2. **Revenue Analytics** - MRR by plan, growth trends, ARR
3. **Conversion Analysis** - Free-to-paid rates, time-to-upgrade
4. **Retention & Churn** - Cohort analysis, churn rates by plan
5. **Engagement Metrics** - User activation, feature adoption
6. **Marketing Performance** - Channel attribution, geographic analysis
7. **LTV Analysis** - Customer lifetime value by plan
8. **Complete Funnel** - End-to-end conversion tracking

## 💻 Run Your Own Queries

Inside the Jupyter notebook or via psql:

```python
# In Jupyter - already connected!
query = """
    SELECT 
        p.name as plan,
        COUNT(s.id) as active_subscriptions,
        SUM(s.mrr) as monthly_recurring_revenue
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.id
    WHERE s.status = 'active'
    GROUP BY p.name
"""
df = pd.read_sql(query, engine)
df
```

```sql
-- In psql
SELECT 
    p.name as plan,
    COUNT(s.id) as active_subscriptions,
    SUM(s.mrr) as monthly_recurring_revenue
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
WHERE s.status = 'active'
GROUP BY p.name;
```

## 📁 Repository Structure

| File/Folder | Purpose |
|-------------|---------|
| `docker-compose.yml` | One-command setup configuration |
| `notebooks/` | Interactive Jupyter notebook with visualizations |
| `schema.sql` | Complete PostgreSQL database schema |
| `sample_data.sql` | Realistic sample data (1000+ users) |
| `analytics_queries.sql` | 50+ analytical SQL queries |
| `key_questions.md` | All analytics questions covered |

## 🛑 Stop Services

```bash
docker compose down
```

To remove all data and start fresh:
```bash
docker compose down -v
```

## 🔧 Troubleshooting

**Port already in use?**
```bash
# Change ports in docker-compose.yml
# Jupyter: Change "8888:8888" to "8889:8888"
# Postgres: Change "5432:5432" to "5433:5432"
```

**Container won't start?**
```bash
# Check logs
docker compose logs postgres
docker compose logs jupyter
```

**Need to rebuild after changes?**
```bash
docker compose up --build
```

## 📚 Next Steps

1. **📊 Explore the Notebook**: Open http://localhost:8888 and run all cells
2. **🔍 Try Custom Queries**: Modify SQL in the notebook to explore data
3. **📈 Export Visualizations**: Save charts from the notebook as PNG/HTML
4. **🔧 Customize Data**: Edit `sample_data.sql` and rebuild
5. **🚀 Production**: Replace sample data with your real customer data

## 💡 Pro Tips

- **Jupyter Tips**: 
  - `Shift + Enter` to run a cell
  - `Cell > Run All` to execute the entire notebook
  - `File > Download as > HTML` to export results

- **Quick Metrics**: The notebook auto-connects to the database, just run the cells!

- **Custom Analysis**: Copy any cell and modify the SQL query for your specific questions

---

**🎉 You're now ready to explore SaaS analytics with PostgreSQL!**

For more details, see the full `README.md` or browse the `analytics_queries.sql` file.