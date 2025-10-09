#!/usr/bin/env python3
"""
Quick Analytics Dashboard
Generates key SaaS metrics from the database and displays them in a formatted report
"""

import os
import sys
from datetime import datetime, timedelta

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("❌ psycopg2 not found. Install with: pip install psycopg2-binary")
    sys.exit(1)

# Database configuration
DB_CONFIG = {
    'host': os.getenv('PGHOST', 'localhost'),
    'port': os.getenv('PGPORT', '5432'),
    'database': os.getenv('PGDATABASE', 'saas_analytics_demo'),
    'user': os.getenv('PGUSER', 'saas_user'),
    'password': os.getenv('PGPASSWORD', 'demo_password')
}


def connect_db():
    """Connect to the PostgreSQL database"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except psycopg2.Error as e:
        print(f"❌ Database connection failed: {e}")
        print("\nTry running: ./setup_database.sh")
        sys.exit(1)


def execute_query(conn, query, description=""):
    """Execute a query and return results"""
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query)
            return cur.fetchall()
    except psycopg2.Error as e:
        print(f"❌ Query failed ({description}): {e}")
        return []


def format_currency(amount):
    """Format currency values"""
    if amount is None:
        return "$0.00"
    return f"${float(amount):,.2f}"


def format_percentage(value):
    """Format percentage values"""
    if value is None:
        return "0.00%"
    return f"{float(value):.2f}%"


def format_number(value):
    """Format numeric values"""
    if value is None:
        return "0"
    return f"{int(value):,}"


def print_header(title):
    """Print a formatted section header"""
    print(f"\n{'='*60}")
    print(f"📊 {title}")
    print(f"{'='*60}")


def print_metric(label, value, unit=""):
    """Print a formatted metric"""
    print(f"  {label:<35} {value}{unit}")


def generate_dashboard():
    """Generate the main analytics dashboard"""
    print("🚀 SaaS Analytics Dashboard")
    print(f"Generated at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    conn = connect_db()

    # Key Metrics Overview
    print_header("Key Metrics Overview")

    # Active users
    active_users = execute_query(conn, """
        SELECT COUNT(*) as count FROM users WHERE status = 'active'
    """, "Active users")
    print_metric("Active Users", format_number(
        active_users[0]['count'] if active_users else 0))

    # Paid subscribers
    paid_subs = execute_query(conn, """
        SELECT COUNT(*) as count FROM subscriptions 
        WHERE status = 'active' AND plan_id != 1
    """, "Paid subscribers")
    print_metric("Paid Subscribers", format_number(
        paid_subs[0]['count'] if paid_subs else 0))

    # Current MRR
    mrr = execute_query(conn, """
        SELECT SUM(CASE 
            WHEN billing_cycle = 'monthly' THEN mrr
            WHEN billing_cycle = 'annual' THEN mrr / 12
            ELSE mrr
        END) as total_mrr
        FROM subscriptions 
        WHERE status = 'active'
    """, "Current MRR")
    mrr_value = mrr[0]['total_mrr'] if mrr and mrr[0]['total_mrr'] else 0
    print_metric("Monthly Recurring Revenue", format_currency(mrr_value))
    print_metric("Annual Recurring Revenue",
                 format_currency(float(mrr_value) * 12))

    # Conversion rate
    conversion = execute_query(conn, """
        WITH conversion_data AS (
            SELECT 
                COUNT(DISTINCT u.id) as total_users,
                COUNT(DISTINCT CASE WHEN s.plan_id != 1 THEN u.id END) as paid_users
            FROM users u
            LEFT JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active'
        )
        SELECT 
            paid_users * 100.0 / NULLIF(total_users, 0) as conversion_rate
        FROM conversion_data
    """, "Conversion rate")
    conv_rate = conversion[0]['conversion_rate'] if conversion and conversion[0]['conversion_rate'] else 0
    print_metric("Free-to-Paid Conversion", format_percentage(conv_rate))

    # Revenue by Plan
    print_header("Revenue by Plan (Last 30 Days)")

    plan_revenue = execute_query(conn, """
        SELECT 
            p.name as plan,
            COUNT(re.id) as transactions,
            SUM(re.amount) as revenue
        FROM revenue_events re
        JOIN subscriptions s ON re.subscription_id = s.id
        JOIN plans p ON s.plan_id = p.id
        WHERE re.occurred_at >= CURRENT_DATE - INTERVAL '30 days'
            AND re.event_type = 'payment'
        GROUP BY p.name
        ORDER BY revenue DESC
    """, "Plan revenue")

    for row in plan_revenue:
        plan_name = row['plan'].title()
        transactions = format_number(row['transactions'])
        revenue = format_currency(row['revenue'])
        print_metric(f"{plan_name} Plan",
                     f"{revenue} ({transactions} transactions)")

    # User Growth
    print_header("User Growth (Last 6 Months)")

    growth_data = execute_query(conn, """
        SELECT 
            DATE_TRUNC('month', created_at) as month,
            COUNT(*) as new_users,
            COUNT(CASE WHEN activated_at IS NOT NULL THEN 1 END) as activated_users
        FROM users 
        WHERE created_at >= CURRENT_DATE - INTERVAL '6 months'
        GROUP BY DATE_TRUNC('month', created_at)
        ORDER BY month DESC
        LIMIT 6
    """, "User growth")

    for row in growth_data:
        month = row['month'].strftime('%Y-%m')
        new_users = format_number(row['new_users'])
        activated = format_number(row['activated_users'])
        activation_rate = (
            row['activated_users'] / row['new_users'] * 100) if row['new_users'] > 0 else 0
        print_metric(
            f"{month}", f"{new_users} signups, {activated} activated ({activation_rate:.1f}%)")

    # Top Performing Channels
    print_header("Top Performing Acquisition Channels")

    channel_data = execute_query(conn, """
        SELECT 
            u.signup_channel,
            COUNT(u.id) as total_signups,
            COUNT(CASE WHEN s.plan_id != 1 THEN 1 END) as paid_conversions,
            ROUND(COUNT(CASE WHEN s.plan_id != 1 THEN 1 END) * 100.0 / COUNT(u.id), 2) as conversion_rate
        FROM users u
        LEFT JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active'
        WHERE u.created_at >= CURRENT_DATE - INTERVAL '90 days'
        GROUP BY u.signup_channel
        HAVING COUNT(u.id) >= 5
        ORDER BY conversion_rate DESC
    """, "Channel performance")

    for row in channel_data:
        channel = row['signup_channel'].replace('_', ' ').title()
        signups = format_number(row['total_signups'])
        conversions = format_number(row['paid_conversions'])
        rate = format_percentage(row['conversion_rate'])
        print_metric(
            f"{channel}", f"{signups} signups → {conversions} paid ({rate})")

    # Recent Activity
    print_header("Recent Activity (Last 7 Days)")

    recent_signups = execute_query(conn, """
        SELECT COUNT(*) as count FROM users 
        WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
    """, "Recent signups")
    print_metric("New Signups", format_number(
        recent_signups[0]['count'] if recent_signups else 0))

    recent_upgrades = execute_query(conn, """
        SELECT COUNT(*) as count FROM subscriptions 
        WHERE plan_id != 1 AND started_at >= CURRENT_DATE - INTERVAL '7 days'
    """, "Recent upgrades")
    print_metric("New Paid Subscriptions", format_number(
        recent_upgrades[0]['count'] if recent_upgrades else 0))

    recent_churn = execute_query(conn, """
        SELECT COUNT(*) as count FROM subscriptions 
        WHERE status = 'cancelled' AND cancelled_at >= CURRENT_DATE - INTERVAL '7 days'
    """, "Recent churn")
    print_metric("Cancelled Subscriptions", format_number(
        recent_churn[0]['count'] if recent_churn else 0))

    projects_created = execute_query(conn, """
        SELECT COUNT(*) as count FROM projects 
        WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
    """, "Projects created")
    print_metric("Projects Created", format_number(
        projects_created[0]['count'] if projects_created else 0))

    conn.close()

    print(f"\n{'='*60}")
    print("✅ Dashboard generated successfully!")
    print("\n💡 Tips:")
    print("  • Run analytics queries in analytics_queries.sql for detailed analysis")
    print("  • Check schema_diagram.png for database structure")
    print("  • Use pgAdmin or psql for interactive querying")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    try:
        generate_dashboard()
    except KeyboardInterrupt:
        print("\n\n👋 Dashboard generation cancelled.")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)
