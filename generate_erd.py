#!/usr/bin/env python3
"""
Database Schema Diagram Generator
Generates an ERD (Entity Relationship Diagram) from the PostgreSQL schema
"""

import os
import subprocess
import sys


def check_dependencies():
    """Check if required dependencies are installed"""
    has_psycopg2 = True
    has_graphviz = True

    try:
        import psycopg2
        print("✓ psycopg2 found")
    except ImportError:
        print("✗ psycopg2 not found. Install with: pip install psycopg2-binary")
        print("ℹ Will generate static ERD without database connection")
        has_psycopg2 = False

    try:
        result = subprocess.run(['dot', '-V'], capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ Graphviz found")
        else:
            print("✗ Graphviz not found. Install with: apt-get install graphviz (Ubuntu) or brew install graphviz (Mac)")
            has_graphviz = False
    except FileNotFoundError:
        print("✗ Graphviz not found. Install with: apt-get install graphviz (Ubuntu) or brew install graphviz (Mac)")
        has_graphviz = False

    return has_graphviz  # Only require Graphviz for diagram generation


def generate_erd_sql():
    """Generate SQL query to extract schema information"""
    return """
    WITH tables_info AS (
        SELECT 
            t.table_name,
            string_agg(
                c.column_name || ' ' || 
                CASE 
                    WHEN c.data_type = 'USER-DEFINED' THEN c.udt_name
                    WHEN c.data_type = 'character varying' THEN 'varchar(' || c.character_maximum_length || ')'
                    WHEN c.data_type = 'numeric' THEN 'decimal(' || c.numeric_precision || ',' || c.numeric_scale || ')'
                    ELSE c.data_type 
                END ||
                CASE WHEN c.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
                CASE WHEN pk.column_name IS NOT NULL THEN ' PK' ELSE '' END,
                '\\n'
                ORDER BY c.ordinal_position
            ) as columns
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name
        LEFT JOIN (
            SELECT ku.table_name, ku.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage ku ON tc.constraint_name = ku.constraint_name
            WHERE tc.constraint_type = 'PRIMARY KEY'
        ) pk ON c.table_name = pk.table_name AND c.column_name = pk.column_name
        WHERE t.table_schema = 'public' 
            AND t.table_type = 'BASE TABLE'
            AND t.table_name NOT LIKE 'pg_%'
        GROUP BY t.table_name
    ),
    relationships AS (
        SELECT DISTINCT
            tc.table_name as from_table,
            kcu.column_name as from_column,
            ccu.table_name as to_table,
            ccu.column_name as to_column
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY'
    )
    SELECT 'TABLES' as type, table_name as name, columns as details FROM tables_info
    UNION ALL
    SELECT 'RELATIONSHIPS' as type, 
           from_table || '->' || to_table as name,
           from_column || '->' || to_column as details
    FROM relationships
    ORDER BY type, name;
    """


def generate_dot_content(schema_data):
    """Generate DOT notation for Graphviz"""
    tables = []
    relationships = []

    for row in schema_data:
        if row[0] == 'TABLES':
            table_name = row[1]
            columns = row[2].replace('\n', '\\l')
            tables.append(
                f'  {table_name} [label="{table_name}|{columns}\\l", shape=record];')
        elif row[0] == 'RELATIONSHIPS':
            rel_parts = row[1].split('->')
            if len(rel_parts) == 2:
                from_table, to_table = rel_parts
                relationships.append(f'  {from_table} -> {to_table};')

    dot_content = """digraph ERD {
  rankdir=TB;
  node [fontname="Arial", fontsize=10];
  edge [fontname="Arial", fontsize=8];
  
  // Define table styling
  node [shape=record, style=filled, fillcolor=lightblue];
  
""" + '\n'.join(tables) + """

  // Define relationships
  edge [arrowhead=crow];
  
""" + '\n'.join(relationships) + """
}"""

    return dot_content


def main():
    """Main function to generate ERD"""
    print("🔧 Checking dependencies...")
    if not check_dependencies():
        print("❌ Cannot generate diagrams without Graphviz")
        sys.exit(1)

    print("\n📊 Generating Entity Relationship Diagram...")

    # For demo purposes, we'll create a static ERD since we don't have a live database
    # In a real scenario, you would connect to PostgreSQL and run the query

    dot_content = """digraph ERD {
  rankdir=TB;
  node [fontname="Arial", fontsize=10];
  edge [fontname="Arial", fontsize=8];
  
  // Define table styling
  node [shape=record, style=filled, fillcolor=lightblue];
  
  users [label="users|id UUID PK\\lemail VARCHAR(255)\\lcreated_at TIMESTAMP\\lactivated_at TIMESTAMP\\llast_login_at TIMESTAMP\\lstatus user_status\\lsignup_channel signup_channel\\lcountry_code VARCHAR(2)\\lutm_source VARCHAR(100)\\lutm_medium VARCHAR(100)\\lutm_campaign VARCHAR(100)\\lreferred_by_user_id UUID", shape=record];
  
  plans [label="plans|id SERIAL PK\\lname plan_type\\lprice_monthly DECIMAL(10,2)\\lprice_annual DECIMAL(10,2)\\lmax_projects INTEGER\\lmax_team_members INTEGER\\lfeatures JSONB", shape=record];
  
  subscriptions [label="subscriptions|id UUID PK\\luser_id UUID\\lplan_id INTEGER\\lstatus subscription_status\\lbilling_cycle billing_cycle\\lstarted_at TIMESTAMP\\lended_at TIMESTAMP\\lcancelled_at TIMESTAMP\\lmrr DECIMAL(10,2)\\lcreated_at TIMESTAMP", shape=record];
  
  projects [label="projects|id UUID PK\\luser_id UUID\\lname VARCHAR(255)\\lcreated_at TIMESTAMP\\lcompleted_at TIMESTAMP\\lis_active BOOLEAN", shape=record];
  
  tasks [label="tasks|id UUID PK\\lproject_id UUID\\luser_id UUID\\ltitle VARCHAR(500)\\lcreated_at TIMESTAMP\\lcompleted_at TIMESTAMP\\lis_completed BOOLEAN", shape=record];
  
  team_memberships [label="team_memberships|id UUID PK\\linviter_user_id UUID\\linvited_user_id UUID\\lproject_id UUID\\linvited_at TIMESTAMP\\laccepted_at TIMESTAMP\\lrole VARCHAR(50)", shape=record];
  
  revenue_events [label="revenue_events|id UUID PK\\luser_id UUID\\lsubscription_id UUID\\lamount DECIMAL(10,2)\\levent_type VARCHAR(50)\\loccurred_at TIMESTAMP\\lstripe_payment_id VARCHAR(255)", shape=record];
  
  user_activities [label="user_activities|id UUID PK\\luser_id UUID\\lactivity_type VARCHAR(100)\\lmetadata JSONB\\loccurred_at TIMESTAMP", shape=record];
  
  funnel_events [label="funnel_events|id UUID PK\\luser_id UUID\\levent_name VARCHAR(100)\\loccurred_at TIMESTAMP\\lsession_id VARCHAR(255)\\lpage_url VARCHAR(500)", shape=record];

  // Define relationships
  edge [arrowhead=crow];
  
  subscriptions -> users [label="user_id"];
  subscriptions -> plans [label="plan_id"];
  projects -> users [label="user_id"];
  tasks -> projects [label="project_id"];
  tasks -> users [label="user_id"];
  team_memberships -> users [label="inviter_user_id"];
  team_memberships -> users [label="invited_user_id"];
  team_memberships -> projects [label="project_id"];
  revenue_events -> users [label="user_id"];
  revenue_events -> subscriptions [label="subscription_id"];
  user_activities -> users [label="user_id"];
  funnel_events -> users [label="user_id"];
  users -> users [label="referred_by_user_id"];
}"""

    # Write DOT file
    with open('schema_diagram.dot', 'w') as f:
        f.write(dot_content)

    print("✓ Generated schema_diagram.dot")

    # Generate PNG using Graphviz
    try:
        subprocess.run(['dot', '-Tpng', 'schema_diagram.dot',
                       '-o', 'schema_diagram.png'], check=True)
        print("✓ Generated schema_diagram.png")

        # Generate SVG for web viewing
        subprocess.run(['dot', '-Tsvg', 'schema_diagram.dot',
                       '-o', 'schema_diagram.svg'], check=True)
        print("✓ Generated schema_diagram.svg")

        print("\n🎉 Schema diagrams generated successfully!")
        print("📁 Files created:")
        print("   - schema_diagram.dot (Graphviz source)")
        print("   - schema_diagram.png (Image)")
        print("   - schema_diagram.svg (Scalable vector)")

    except subprocess.CalledProcessError as e:
        print(f"✗ Error generating diagram: {e}")
        print("Make sure Graphviz is installed and the 'dot' command is available")
        sys.exit(1)
    except FileNotFoundError:
        print("✗ 'dot' command not found. Please install Graphviz")
        sys.exit(1)


if __name__ == "__main__":
    main()
