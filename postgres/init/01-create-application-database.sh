#!/bin/sh
set -eu

: "${WEBAPP_DB:?WEBAPP_DB must be set}"

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=application_database="$WEBAPP_DB" \
  --command 'CREATE DATABASE :"application_database" OWNER CURRENT_USER;'
