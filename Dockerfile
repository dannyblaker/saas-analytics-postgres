FROM jupyter/scipy-notebook:latest

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

USER jovyan

# Install Python packages for data analysis and visualization
RUN pip install --no-cache-dir \
    psycopg2-binary==2.9.9 \
    pandas==2.1.4 \
    matplotlib==3.8.2 \
    seaborn==0.13.0 \
    plotly==5.18.0 \
    sqlalchemy==2.0.23 \
    ipywidgets==8.1.1 \
    kaleido==0.2.1

# Copy wait script
COPY --chown=jovyan:users wait-for-postgres.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wait-for-postgres.sh

# Create work directory
RUN mkdir -p /home/jovyan/work

WORKDIR /home/jovyan/work

EXPOSE 8888

# Use wait script as entrypoint
ENTRYPOINT ["/usr/local/bin/wait-for-postgres.sh"]