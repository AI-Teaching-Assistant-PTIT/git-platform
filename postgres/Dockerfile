FROM ghcr.io/cloudnative-pg/postgresql:16
USER root
RUN apt-get update && apt-get install -y postgresql-16-pgvector && rm -rf /var/lib/apt/lists/*
USER 26
