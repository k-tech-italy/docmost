#!/bin/bash
### NB: needs pgpass to be setup

DB_HOST=`echo "${DATABASE_URL}" | sed -E 's/.*@([^:]+).*/\1/'`
DB_PORT=`echo "${DATABASE_URL}" | sed -E 's/.*:([0-9]+)\/.*/\1/'`
DB_NAME=`echo "${DATABASE_URL}" | sed -E 's/.*\/([^\?]*).*/\1/'`

echo "Initialising DB ${DB_NAME}"
echo "Initialising DB ${DB_HOST}"

echo Deleting database "${DB_NAME}"
psql -h ${DB_HOST} -p ${DB_PORT} -U postgres -c "DROP DATABASE IF EXISTS ${DB_NAME}"
psql -h ${DB_HOST} -p ${DB_PORT} -U postgres -c "CREATE DATABASE ${DB_NAME}"

pg_dump -p ${REMOTE_PORT} -h ${REMOTE_HOST} -U postgres -d docmost -O -x | psql -h localhost -p ${DB_PORT} -U postgres --set ON_ERROR_STOP=on -d ${DB_NAME}
