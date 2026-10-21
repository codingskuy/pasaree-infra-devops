# Pemantauan kesehatan dan alarm pembayaran

Rujukan: PSR-OPS-005, ADR-0001 butir 7, BR-304. Prosedur penanganan: `docs/runbook.md`.

## 1. Cek `/kesehatan`

Kontrak (`docs/api/openapi.yaml` backend): 200 dengan `{"layanan":"pasaree-backend-service","status":"baik","db":"pasaree"}`. Backend menjalankan `SELECT 1` ke DB `pasaree` sebelum menjawab, jadi 200 + `status=baik` + `db=pasaree` berarti layanan dan DB sehat.

- Skrip: `scripts/cek-kesehatan.sh [url]` (keluar 1 bila bukan 2xx, status bukan `baik`, atau db bukan `pasaree`).
- Berkala: workflow `.github/workflows/kesehatan.yml` tiap 10 menit (batas praktis GitHub Actions; jadwal bisa tertunda). Aktif setelah variabel repo `PASAREE_HEALTH_URL` diisi. Secret opsional `ALERT_WEBHOOK_URL` mengirim pesan ke kanal tim.
- Alarm: workflow merah (notifikasi GitHub ke pemantau) dan webhook. Respons: ikuti runbook bagian 3 (401/akses) atau periksa DB/backend; target ack 15 menit jam kerja (usulan).
- Untuk produksi disarankan pemantau eksternal dengan interval 1 menit; pilihan alat butuh ADR (platform belum diputuskan).

## 2. Alarm pembayaran

| Alarm | Kondisi | Tingkat | Tindakan |
|---|---|---|---|
| Payout T+1 terlambat | payout belum dieksekusi Lumbung setelah akhir hari kerja berikutnya sejak escrow dilepas | tinggi | tiket rekonsiliasi (runbook bagian 5) |
| Escrow menggantung | escrow berstatus DIBAYAR/ditahan lebih dari 2x24 jam tanpa pelepasan atau pengembalian | tinggi | tiket rekonsiliasi |
| Selisih rekonsiliasi | selisih harian Pasaree-Lumbung lebih dari Rp1.000 | tinggi | tiket rekonsiliasi |

Kueri alarm (KONTRAK YANG DIHARAPKAN dari backend; nama tabel dan kolom adalah ASUMSI karena migrasi backend saat ini baru memuat auth dan katalog, belum transaksi/escrow/payout; sesuaikan saat skema pembayaran terbit):

```sql
-- escrow menggantung > 2x24 jam
select escrow_id, dibuat_pada from escrow
 where status = 'DITAHAN' and dibuat_pada < now() - interval '48 hours';

-- payout T+1 terlambat (hari kerja dihitung di aplikasi/kalender; contoh kasar 1 hari)
select payout_id, jatuh_tempo from payout
 where status <> 'TERKIRIM' and jatuh_tempo < now();
```

Jalankan kueri sebagai pekerjaan terjadwal berakun DB read-only milik DB `pasaree`; hasil tidak kosong memicu alarm. Dilarang membaca DB divisi lain. Alarm hanya memuat ID transaksi dan jumlah IDR, tanpa data pembeli.

## 3. Log terstruktur

- Backend memakai `tracing` (JSON ke stdout); kumpulkan stdout kontainer lewat agen log platform.
- Larangan dimuat di log: nomor kartu, nomor rekening, token/JWT, `Authorization`, kata sandi, `LUMBUNG_SERVICE_KEY`. Boleh: `escrow_id`, `request_id`, kode status, jumlah IDR.
- Pagar di pipeline log: tolak/redaksi pola 13-19 digit beruntun dan header `authorization` sebelum disimpan.
- Retensi usulan 30 hari; akses terbatas tim Pasaree.

## 4. Belum tercakup (butuh keputusan/kode)

- Jadwal kueri alarm pembayaran belum dijalankan: menunggu skema transaksi/escrow/payout di backend.
- Penilaian apakah backend sudah mengeluarkan log JSON dan membuang data sensitif ada di repo backend (tiket terpisah).
