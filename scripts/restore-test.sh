#!/usr/bin/env bash
# Uji pulih mingguan (PSR-OPS-004): pulihkan cadangan ke DB sementara
# `pasaree_restore_test`, hitung tabel, lalu hapus DB sementara. DB `pasaree`
# asli tidak disentuh. Pemakaian: scripts/restore-test.sh [berkas.dump]
set -euo pipefail
cd "$(dirname "$0")/.."

FILE="${1:-}"
if [ -z "$FILE" ]; then
  FILE="$(find "${BACKUP_DIR:-backups}" -name 'pasaree-*.dump' -type f | sort | tail -n1)"
fi
test -f "$FILE" || { echo "cadangan tidak ditemukan" >&2; exit 1; }

# psql_db <database> <sql>
psql_db() {
  docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -v ON_ERROR_STOP=1 -tA -d "$1" -c "$2"' _ "$1" "$2"
}

psql_db postgres 'DROP DATABASE IF EXISTS pasaree_restore_test'
psql_db postgres 'CREATE DATABASE pasaree_restore_test'
trap 'psql_db postgres "DROP DATABASE IF EXISTS pasaree_restore_test" >/dev/null' EXIT

docker compose exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d pasaree_restore_test --no-owner' < "$FILE"
N="$(psql_db pasaree_restore_test "select count(*) from information_schema.tables where table_schema='public'" | tr -d '[:space:]')"
test "${N:-0}" -gt 0 || { echo "pulih gagal: tidak ada tabel" >&2; exit 1; }
echo "OK pulih dari $FILE: $N tabel"
