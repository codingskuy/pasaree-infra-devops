#!/usr/bin/env bash
# Cek /kesehatan: HTTP 200, status "baik", db "pasaree" (kontrak openapi.yaml).
# Pemakaian: scripts/cek-kesehatan.sh [url]   (bawaan http://localhost:8101/kesehatan)
set -euo pipefail
URL="${1:-http://localhost:8101/kesehatan}"
BODY="$(curl -fsS --max-time 10 --retry 2 --retry-delay 3 "$URL")" || { echo "GAGAL: $URL tidak dapat dijangkau / bukan 2xx" >&2; exit 1; }
STATUS="$(printf '%s' "$BODY" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')"
DB="$(printf '%s' "$BODY" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("db",""))')"
if [ "$STATUS" != "baik" ] || [ "$DB" != "pasaree" ]; then
  echo "GAGAL: status=$STATUS db=$DB (diharapkan baik/pasaree)" >&2
  exit 1
fi
echo "OK $URL status=$STATUS db=$DB"
