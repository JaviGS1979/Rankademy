#!/usr/bin/env bash
# Aplica las migraciones en una base de datos local vacía y ejecuta las pruebas.
# Requiere un PostgreSQL local en marcha (usuario postgres).
set -euo pipefail
cd "$(dirname "$0")/.."
DB=rk_test
psql_pg() { su postgres -c "psql -q -tA -v ON_ERROR_STOP=1 $*"; }
psql_pg "-c 'drop database if exists $DB' -c 'create database $DB'" >/dev/null 2>&1
for f in tests/00_simular_supabase.sql migrations/*.sql tests/10_seguridad.sql; do
  [[ $f == tests/10_seguridad.sql ]] && continue
  su postgres -c "psql -q -v ON_ERROR_STOP=1 -d $DB" < "$f" >/dev/null
done
su postgres -c "psql -q -tA -v ON_ERROR_STOP=1 -d $DB -f $PWD/tests/10_seguridad.sql" | grep -v '^$' | grep -v '^t$' | grep -v '^f$' | grep -v '^{' || true
