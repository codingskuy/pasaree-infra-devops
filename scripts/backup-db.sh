#!/usr/bin/env bash
# Cadangan harian DB `pasaree` (PSR-OPS-004). Jalankan dari akar repo infra.
# Hasil: backups/pasaree-YYYYMMDD-HHMMSS.dump (format custom pg_dump).
# Retensi: simpan 14 harian + 8 mingguan (atur di penjadwal/penyimpanan, bukan di sini).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT_DIR="${BACKUP_DIR:-backups}"
mkdir -p "$OUT_DIR"
FILE="$OUT_DIR/pasaree-$(date +%Y%m%d-%H%M%S).dump"
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d pasaree -Fc' > "$FILE"
test -s "$FILE" || { echo "cadangan kosong: $FILE" >&2; exit 1; }
echo "OK $FILE ($(wc -c < "$FILE") bita)"
