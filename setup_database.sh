#!/bin/bash

# SaaS Analytics Demo - Database Setup Script
# This script sets up a PostgreSQL database with sample data for analytics demonstration

set -e

# Configuration
DB_NAME="saas_analytics_demo"
DB_USER="saas_user"
DB_PASSWORD="demo_password"
DB_HOST="localhost"
DB_PORT="5432"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if PostgreSQL is installed and running
check_postgresql() {
    print_header "Checking PostgreSQL Installation"
    
    if ! command -v psql &> /dev/null; then
        print_error "PostgreSQL is not installed or not in PATH"
        echo "Please install PostgreSQL first:"
        echo "  Ubuntu/Debian: sudo apt-get install postgresql postgresql-contrib"
        echo "  macOS: brew install postgresql"
        echo "  Or use Docker: docker run --name postgres-demo -e POSTGRES_PASSWORD=mysecretpassword -d -p 5432:5432 postgres"
        exit 1
    fi
    
    print_success "PostgreSQL found"
    
    # Check if PostgreSQL service is running
    if ! pg_isready -h $DB_HOST -p $DB_PORT &> /dev/null; then
        print_warning "PostgreSQL service might not be running"
        echo "Try starting it with:"
        echo "  Ubuntu/Debian: sudo systemctl start postgresql"
        echo "  macOS: brew services start postgresql"
        echo "  Docker: docker start postgres-demo"
    else
        print_success "PostgreSQL service is running"
    fi
}

# Create database and user
setup_database() {
    print_header "Setting Up Database"
    
    echo "Please enter your PostgreSQL superuser password when prompted..."
    
    # Create user if not exists
    psql -h $DB_HOST -p $DB_PORT -U postgres -c "
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
                CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
            END IF;
        END
        \$\$;
    " 2>/dev/null || print_warning "User creation might have failed (possibly already exists)"
    
    # Create database if not exists
    psql -h $DB_HOST -p $DB_PORT -U postgres -c "
        SELECT 'CREATE DATABASE $DB_NAME'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\\gexec
    " 2>/dev/null || print_warning "Database creation might have failed (possibly already exists)"
    
    # Grant privileges
    psql -h $DB_HOST -p $DB_PORT -U postgres -c "
        GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
        GRANT CREATE ON SCHEMA public TO $DB_USER;
    " 2>/dev/null || print_warning "Privilege grant might have failed"
    
    print_success "Database setup completed"
}

# Run schema creation
create_schema() {
    print_header "Creating Database Schema"
    
    if [ ! -f "schema.sql" ]; then
        print_error "schema.sql file not found!"
        exit 1
    fi
    
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f schema.sql
    print_success "Schema created successfully"
}

# Load sample data
load_sample_data() {
    print_header "Loading Sample Data"
    
    if [ ! -f "sample_data.sql" ]; then
        print_error "sample_data.sql file not found!"
        exit 1
    fi
    
    echo "This may take a few minutes to generate realistic sample data..."
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f sample_data.sql
    print_success "Sample data loaded successfully"
}

# Verify installation
verify_setup() {
    print_header "Verifying Setup"
    
    # Count records in key tables
    USER_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM users;")
    SUBSCRIPTION_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM subscriptions;")
    PROJECT_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM projects;")
    
    echo "Database Statistics:"
    echo "  Users: $(echo $USER_COUNT | xargs)"
    echo "  Subscriptions: $(echo $SUBSCRIPTION_COUNT | xargs)"
    echo "  Projects: $(echo $PROJECT_COUNT | xargs)"
    
    print_success "Database verification completed"
}

# Generate ERD
generate_diagram() {
    print_header "Generating Schema Diagram"
    
    if [ -f "generate_erd.py" ]; then
        python3 generate_erd.py
        print_success "Schema diagram generated"
    else
        print_warning "generate_erd.py not found, skipping diagram generation"
    fi
}

# Show connection info
show_connection_info() {
    print_header "Connection Information"
    
    echo "Database Details:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  Username: $DB_USER"
    echo "  Password: $DB_PASSWORD"
    echo ""
    echo "Connect using:"
    echo "  psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
    echo ""
    echo "Or set environment variables:"
    echo "  export PGHOST=$DB_HOST"
    echo "  export PGPORT=$DB_PORT"
    echo "  export PGDATABASE=$DB_NAME"
    echo "  export PGUSER=$DB_USER"
    echo "  export PGPASSWORD=$DB_PASSWORD"
}

# Main execution
main() {
    print_header "SaaS Analytics Demo - Database Setup"
    echo "This script will set up a PostgreSQL database with sample data for analytics demonstration."
    echo ""
    
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    check_postgresql
    setup_database
    create_schema
    load_sample_data
    verify_setup
    generate_diagram
    show_connection_info
    
    print_header "Setup Complete!"
    echo "Your SaaS Analytics Demo database is ready!"
    echo "Check out the analytics_queries.sql file for example queries."
    echo "View the schema diagram (if generated) for database structure."
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help|--reset]"
        echo "  --help    Show this help message"
        echo "  --reset   Drop and recreate the database"
        exit 0
        ;;
    --reset)
        print_warning "Resetting database..."
        psql -h $DB_HOST -p $DB_PORT -U postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
        psql -h $DB_HOST -p $DB_PORT -U postgres -c "DROP USER IF EXISTS $DB_USER;"
        ;;
esac

main