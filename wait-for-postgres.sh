#!/bin/bash
# Wait for PostgreSQL to be ready before starting Jupyter

set -e

host="$POSTGRES_HOST"
port="$POSTGRES_PORT"
user="$POSTGRES_USER"
db="$POSTGRES_DB"

echo "Waiting for PostgreSQL to be ready..."

until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$host" -p "$port" -U "$user" -d "$db" -c '\q'; do
  >&2 echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

>&2 echo "✅ PostgreSQL is up - starting Jupyter Notebook"

# Start Jupyter with no token for easy access
exec start-notebook.sh --NotebookApp.token='' --NotebookApp.password=''
